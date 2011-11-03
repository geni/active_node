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

    def self.init(host)
      @servers ||= {}
      @servers[host] ||= new(host)
    end

    def initialize(host)
      @host = host || DEFAULT_HOST
    end

    def read(path, params = {})
      if @@bulk_params
        enqueue_read(path, params)
      else
        http(:method => :read, :path => path, :params => params)
      end
    end

    def write(path, data, params = {})
      raise Error, 'cannot write inside a bulk_read block' if @@bulk_params

      params[:request_time] ||= time_usec
      http(:method => :write, :path => path, :data => data || {}, :params => params)

    rescue ActiveNode::ConnectionError => e
      params[:retry] ||= 0
      raise e unless params[:retry] < RETRY_LIMIT

      params[:retry] += 1
      sleep(rand(RETRY_WAIT.last - RETRY_WAIT.first + 1) + RETRY_WAIT.first)
      retry
    end

    def self.clear_bulk_queue!
      @@bulk        = {}
      @@bulk_params = nil
      @@bulk_count  = 0
    end
    clear_bulk_queue!

    def self.bulk_read(params)
      raise Error, 'cannot nest calls to bulk_read' if @@bulk_params
      @@bulk_params = params
      yield
      results = []
      @@bulk.each do |server, bulk|
        server.bulk_read(bulk[:requests], params).zip(bulk[:ids]) do |result, id|
          results[id] = result
        end
      end
      results
    ensure
      clear_bulk_queue!
    end

    def bulk_read(requests, params)
      http(:method => :bulk_read, :path => "/bulk-read", :data => requests, :params => params)
    end

    def enqueue_read(path, params = {})
      id = @@bulk_count
      @@bulk_count += 1

      # Save space by removing params that are the same as the default.
      params = params.reject {|k, v| v == @@bulk_params[k]}
      @@bulk[self] ||= {:requests => [], :ids => []}
      @@bulk[self][:requests] << [path, params]
      @@bulk[self][:ids]      << id
      id
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

    def fallback_hosts
      ActiveNode.fallback_hosts
    end

  private

    def time_usec
      t = Time.now
      t.usec + t.to_i * 1_000_000
    end

    HTTP_METHOD = {
      :write     => :post,
      :read      => :get,
      :bulk_read => :post,
    }

    def http(opts)
      url     = "#{host}#{opts[:path]}#{query_string(opts[:params])}"
      headers = ActiveNode::Base.headers.merge('Content-type' => 'application/json')
      body    = opts[:data] ? [opts[:data].to_json] : []
      method  = HTTP_METHOD[opts[:method]]
      error   = nil

      curl = Curl::Easy.new(url) do |c|
        c.headers = headers
        c.timeout = timeout * 1000
      end

      begin
        curl.send("http_#{method}", *body)
        if curl.response_code.between?(200, 299)
          results = parse_body(curl.body_str)
          results.meta.merge!(opts.merge(:time => curl.total_time))
          ActiveNode::Base.after_success(results)
          return results
        else
          error = ActiveNode::Error.new("#{method} to #{url} failed with HTTP #{curl.response_code}")
          error.cause = parse_body(curl.body_str) || {}
        end
      rescue Curl::Err::ConnectionFailedError, Curl::Err::HostResolutionError => e
        fallback_hosts.each do |host|
          server = Server.init(host)
          next if server == self
          begin
            return server.send(:http, opts.merge(:fallback => true))
          rescue ActiveNode::ConnectionError
          end
        end unless opts[:fallback]

        error = ActiveNode::ConnectionError.new("#{e.class} on #{method} to #{url}: #{e.message}")
      rescue Curl::Err::CouldntReadError, Curl::Err::RecvError, Curl::Err::GotNothingError => e
        error = ActiveNode::ReadError.new("#{e.class} on #{method} to #{url}: #{e.message}")
      rescue Curl::Err::TimeoutError => e
        error = ActiveNode::TimeoutError.new("#{e.class} on #{method} to #{url}: #{e.message}")
        error.cause = {:timeout => timeout}
      end
      error.cause ||= {}
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
