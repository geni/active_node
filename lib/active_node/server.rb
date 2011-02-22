require 'rubygems'
require 'typhoeus'
require 'json'

module ActiveNode
  class Server
    DEFAULT_HOST = "localhost:9229"
    TIMEOUT = 30 # seconds
    RETRY_LIMIT = 5
    RETRY_WAIT  = 1..3

    attr_reader :host

    def initialize(host)
      @host = host || DEFAULT_HOST
    end

    def read(path, opts = {})
      http(:post, path, :data => revision(opts))
    end

    def write(path, data, opts = {})
      opts[:request_time] ||= time_usec
      http(:put, path, :data => data || {}, :params => opts)

    rescue ActiveNode::ConnectionError => e
      opts[:retry] ||= 0
      raise e unless opts[:retry] < RETRY_LIMIT

      opts[:retry] += 1
      sleep(rand(RETRY_WAIT.last - RETRY_WAIT.first + 1) + RETRY_WAIT.first)
      retry
    end

    def self.clear_bulk_queue!
      @@bulk_count    = 0
      @@bulk_requests = {}
    end
    clear_bulk_queue!

    def enqueue_read(path, opts = {})
      prefix  = host.split('/', 2)[1]
      path    = "/#{prefix}#{path}" if prefix
      request = {:path => path, :params => opts, :id => @@bulk_count}

      (@@bulk_requests[self] ||= []) << request
      @@bulk_count += 1
      request
    end

    def self.bulk_read(opts = {})
      results = []
      @@bulk_requests.each do |server, requests|
        server.bulk_read(requests, opts).zip(requests) do |result, request|
          results[request[:id]] = result
        end
      end
      clear_bulk_queue!
      results
    end

    def bulk_read(requests, opts = {})
      http(:post, "/bulk-read", :data => requests, :params => revision(opts))
    end

  private

    def revision(opts)
      if ActiveNode.respond_to?(:latest_revision) and opts['revision'].nil?
        if (revision = ActiveNode.latest_revision)
          opts["revision"] = revision
        end
      end
      opts
    end

    def time_usec
      t = Time.now
      t.usec + t.to_i * 1_000_000
    end

    def http(method, path, opts = {})
      body    = opts[:data].to_json if opts[:data]
      params  = opts[:params]
      headers = {'Content-type' => 'application/json'}
      headers = headers.merge(ActiveNode.headers) if ActiveNode.respond_to?(:headers)

      response = Typhoeus::Request.run("#{host}#{path}",
        :body    => body,
        :method  => method,
        :params  => params,
        :headers => headers,
        :timeout => TIMEOUT * 1000
      )
      if response.success?
        results = parse_body(response.body)
        ActiveNode.latest_revision(results["revision"]) if results.kind_of?(Hash) and ActiveNode.respond_to?(:latest_revision)
        return results
      end

      if response.code == 0
        problem = response.time.round == TIMEOUT ? :timeout : :connection_refused
        e = ActiveNode::ConnectionError.new("#{problem} on #{method} to #{response.effective_url}")
        e.cause = {:request_timeout => TIMEOUT,
                   :response_time_round => response.time.round,
                   :request => response.request}
      else
        e = ActiveNode::Error.new("#{method} to #{response.effective_url} failed with HTTP #{response.code}")
        e.cause = parse_body(response.body) || {}
      end
      e.cause[:request_data]   = opts[:data]
      e.cause[:request_params] = opts[:params]
      raise e
    end

    def parse_body(body)
      JSON.load(body) unless body.empty? or body == 'null'
    end
  end
end
