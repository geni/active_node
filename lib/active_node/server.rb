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
      http(:get, path, :params => params)
    end

    def write(path, data, params = nil)
      http(:put, path,
        :body    => (data || {}).to_json,
        :params  => params,
        :headers => {'Content-type' => 'application/json'}
      )
    end

  private

    def http(method, path, opts = {})
      response = Typhoeus::Request.run("#{host}#{path}", opts.merge(:timeout => TIMEOUT * 1000, :method => method))
      if response.success?
        return parse_body(response.body)
      elsif response.code == 0
        if response.time.round == TIMEOUT
          raise ActiveNode::ConnectionError, "timeout on #{method} to #{response.effective_url}"
        else
          raise ActiveNode::ConnectionError, "connection refused on #{method} to #{response.effective_url}"
        end
      else
        error = parse_body(response.body).pretty_inspect
        raise ActiveNode::Error, "#{method} to #{response.effective_url} failed with HTTP #{response.code}\n#{error}"
      end
    end

    def parse_body(body)
      return nil if body.empty? or body == 'null'
      JSON.load(body)
    end
  end
end
