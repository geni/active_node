require 'rubygems'
require 'typhoeus'
require 'json'

module ActiveNode
  class Server
    DEFAULT_HOST = "localhost:9229"
    attr_reader :host

    def initialize(host)
      @host = host || DEFAULT_HOST
    end

    def read(path, params = nil)
      http(path, :params => params)
    end

    def write(path, data, params = nil)
      http(path,
        :method  => :post,
        :body    => data.to_json,
        :params  => params,
        :headers => {'Content-type' => 'application/json'}
      )
    end

  private

    def http(path, opts = {})
      response = Typhoeus::Request.run("#{host}#{path}", opts.merge(:timeout => 5000))
      if response.success?
        return parse_body(response.body)
      elsif response.code == 0
        if time > 0
          raise ActiveNode::ConnectionError, "timeout on #{method} to http://#{host}#{path}"
        else
          raise ActiveNode::ConnectionError, "connection refused on #{method} to http://#{host}#{path}"
        end
      else
        error = parse_body(response.body).pretty_inspect
        raise ActiveNode::Error, "#{method} to http://#{host}#{args.first} failed with HTTP #{response.code}\n#{error}"
      end
    end

    def parse_body(body)
      return nil if body.empty? or body == 'null'
      JSON.load(body)
    end
  end
end
