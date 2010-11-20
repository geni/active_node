require 'rubygems'
require 'typhoeus'
require 'json'

module ActiveNode
  class Server
    DEFAULT_HOST = "localhost:9229"
    TIMEOUT = 5 # seconds
    attr_reader :host

    def initialize(host)
      @host = host || DEFAULT_HOST
    end

    def read(path, params = nil)
      if ActiveNode.respond_to?(:latest_revision)
        params ||= {}
        params["revision"] = ActiveNode.latest_revision
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
      data = opts.delete(:data)
      opts[:body] = data.to_json if data

      response = Typhoeus::Request.run("#{host}#{path}", opts.merge(:timeout => TIMEOUT * 1000, :method => method))
      if response.success?
        results = parse_body(response.body)
        ActiveNode.latest_revision(results["revision"]) if ActiveNode.respond_to?(:latest_revision)
        return results
      end

      if response.code == 0
        problem = response.time.round == TIMEOUT ? "timeout" : "connection refused"
        e = ActiveNode::ConnectionError.new("#{problem} on #{method} to #{response.effective_url}")
        e.cause = {:request_timeout => TIMEOUT,
                   :response_time_round => response.time.round,
                   :request => response.request}
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
