require 'rubygems'
require 'typhoeus'
require 'json'

module ActiveNode
  class Server
    DEFAULT_HOST = "localhost:9229"
    TIMEOUT = 30 # seconds
    RETRY_LIMIT = 5
    attr_reader :host

    def initialize(host)
      @host = host || DEFAULT_HOST
    end

    def read(path, params = nil)
      if ActiveNode.respond_to?(:latest_revision)
        if (revision = ActiveNode.latest_revision)
          params ||= {}
          params["revision"] = revision
        end
      end
      http(:get, path, :params => params)
    end

    def write(path, data, params = nil)
      http(:put, path,
        :data    => data || {},
        :params  => params,
        :headers => {'Content-type' => 'application/json'}
      )
    end

  private

    def http(method, path, opts = {})
      body      = opts[:data].to_json if opts[:data]
      params    = opts[:params]
      retry_num = opts[:retry_num] || 0
      headers   = (opts[:headers] || {}).merge('Retry-num' => retry_num.to_s)
      headers.merge!(ActiveNode.headers) if ActiveNode.respond_to?(:headers)

      response = Typhoeus::Request.run("#{host}#{path}",
        :method  => method,
        :params  => params,
        :headers => headers,
        :timeout => TIMEOUT * 1000
      )
      if response.success?
        results = parse_body(response.body)
        ActiveNode.latest_revision(results["revision"]) if results and ActiveNode.respond_to?(:latest_revision)
        return results
      end

      if response.code == 0
        problem = response.time.round == TIMEOUT ? :timeout : :connection_refused
        if problem != :timeout and retry_num < RETRY_LIMIT
          http(method, path, opts.merge(:retry_num => retry_num + 1))
        else
          e = ActiveNode::ConnectionError.new("#{problem} on #{method} to #{response.effective_url}")
          e.cause = {:request_timeout => TIMEOUT,
                     :response_time_round => response.time.round,
                     :request => response.request}
        end
      else
        e = ActiveNode::Error.new("#{method} to #{response.effective_url} failed with HTTP #{response.code}")
        e.cause = parse_body(response.body) || {}
      end
      e.cause[:request_data]   = data
      e.cause[:request_params] = opts[:params]
      raise e
    end

    def parse_body(body)
      JSON.load(body) unless body.empty? or body == 'null'
    end
  end
end
