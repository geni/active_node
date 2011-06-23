require 'rubygems'
require 'curb'
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
      http(:get, path, :params => revision(opts))
    end

    def write(path, data, opts = {})
      opts[:request_time] ||= time_usec
      http(:post, path, :data => data || {}, :params => opts)

    rescue ActiveNode::ConnectionError => e
      opts[:retry] ||= 0
      raise e unless opts[:retry] < RETRY_LIMIT

      opts[:retry] += 1
      sleep(rand(RETRY_WAIT.last - RETRY_WAIT.first + 1) + RETRY_WAIT.first)
      retry
    end

    def self.clear_bulk_queue!
      @@bulk = {}
      @@bulk_count = 0
    end
    clear_bulk_queue!

    def enqueue_read(path, opts = {})
      id = @@bulk_count
      @@bulk_count += 1

      @@bulk[self] ||= {:requests => [], :ids => []}
      @@bulk[self][:requests] << [path, opts]
      @@bulk[self][:ids]      << id
      id
    end

    def self.bulk_read(opts = {})
      results = []
      @@bulk.each do |server, bulk|
        server.bulk_read(bulk[:requests], opts).zip(bulk[:ids]) do |result, id|
          results[id] = result
        end
      end
      clear_bulk_queue!
      results
    end

    def bulk_read(requests, opts = {})
      http(:post, "/bulk-read", :data => requests, :params => revision(opts))
    end

    def self.timeout
      @timeout || TIMEOUT
    end

    def timeout
      self.class.timeout
    end

    def self.timeout=(timeout)
      @timeout = timeout
    end

    def self.with_timeout(timeout)
      old, @timeout = @timeout, timeout
      yield
    ensure
      @timeout = old
    end

  private

    def revision(opts)
      if ActiveNode.respond_to?(:latest_revision) and opts['revision'].nil?
        if (revision = ActiveNode.latest_revision)
          opts['revision'] = revision
        end
      elsif opts['revision'] == :latest
        opts.delete('revision')
      end
      opts
    end

    def time_usec
      t = Time.now
      t.usec + t.to_i * 1_000_000
    end

    def http(method, path, opts = {})
      url     = "#{host}#{path}#{query_string(opts[:params])}"
      body    = opts[:data].to_json if opts[:data]
      headers = {'Content-type' => 'application/json'}
      headers = headers.merge(ActiveNode.headers) if ActiveNode.respond_to?(:headers)
      body    = opts[:data] ? [opts[:data].to_json] : []
      error   = nil

      curl = Curl::Easy.new(url) do |c|
        c.headers = headers
        c.timeout = timeout * 1000
      end

      begin
        curl.send("http_#{method}", *body)
        if curl.response_code.between?(200, 299)
          results = parse_body(curl.body_str)
          ActiveNode.log_request(method, path, opts, curl.total_time) if ActiveNode.respond_to?(:log_request)
          ActiveNode.latest_revision(results["revision"]) if results.kind_of?(Hash) and ActiveNode.respond_to?(:latest_revision)
          return results
        else
          error = ActiveNode::Error.new("#{method} to #{url} failed with HTTP #{curl.response_code}")
          error.cause = parse_body(curl.body_str) || {}
        end
      rescue Curl::Err::CouldntReadError, Curl::Err::ConnectionFailedError, Curl::Err::GotNothingError => e
        error = ActiveNode::ConnectionError.new("#{e.class} on #{method} to #{url}: #{e.message}")
        error.cause = {}
      rescue Curl::Err::TimeoutError => e
        error = ActiveNode::TimeoutError.new("#{e.class} on #{method} to #{url}: #{e.message}")
        error.cause = {:timeout => timeout}
      end

      error.cause.merge!(opts)
      raise error
    end

    def query_string(params)
      if params
        raise ArgumentError, "params must be Hash" unless params.kind_of?(Hash)
        "?" << params.collect do |key, val|
          "#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
        end.join('&')
      end
    end

    def parse_body(body)
      JSON.load(body) unless body.empty? or body == 'null'
    end
  end
end
