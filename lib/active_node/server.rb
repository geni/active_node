require 'net/http'
require 'cgi'
require 'json'

module ActiveNode
  class Server
    DEFAULT_HOST = "localhost:9229"
    attr_reader :host

    def initialize(host)
      @host = host || DEFAULT_HOST
      @http = Net::HTTP.start(*@host.split(':'))
    end

    def read(path, opts = nil)
      path << query_string(opts) if opts
      http(:get, path)
    end

    def write(path, data, opts = nil)
      path << query_string(opts) if opts
      data = data.to_json
      http(:post, path, data, 'Content-type' => 'application/json')
    end

  private

    def http(method, *args)
      response = @http.send(method, *args)
      if response.code =~ /\A2\d{2}\z/
        return parse_body(response.body)
      elsif response.code =~ /\A4\d{2}\z/
        error = parse_body(response.body).pretty_inspect
      end
      raise ActiveNode::Error, "#{method} to http://#{host}#{args.first} failed with HTTP #{response.code}\n#{error}"
    rescue Errno::ECONNREFUSED => e
      raise ActiveNode::ConnectionError, "connection refused on #{method} to http://#{host}#{args.first}"
    rescue TimeoutError => e
      raise ActiveNode::ConnectionError, "timeout on #{method} to http://#{host}#{args.first}"
    end

    def parse_body(body)
      return nil if body.empty? or body == 'null'
      JSON.load(body)
    end

    def query_string(opts)
      if opts
        raise ArgumentError, "opts must be Hash" unless opts.kind_of?(Hash)
        "?" << opts.collect do |key, val|
          "#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
        end.join('&')
      end
    end
  end
end
