require 'rubygems'
require 'curb'
require 'json'
require 'deep_hash'

module ActiveNode
  class Server
    DEFAULT_HOST = "localhost:9229"
    TIMEOUT = 30 # seconds
    RETRY_LIMIT = 5
    RETRY_WAIT  = 1..3

    attr_reader :type, :host

    def self.init(type, host)
      @servers ||= Hash.deep(1)
      @servers[type][host] ||= new(type, host)
    end

    def initialize(type, host)
      @type = type
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

      params = params.clone
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
      ActiveNode::Utils.parallel(@@bulk) do |server, bulk|
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
      if @fallback_hosts.nil?
        @fallback_hosts = ActiveNode.fallback_hosts(type).dup
        @fallback_hosts.delete(host)
      end
      @fallback_hosts
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
          results.meta.merge!(opts.merge(:duration => curl.total_time))
          ActiveNode::Base.after_success(results)
          return results
        else
          response = parse_body(curl.body_str)
          raise_error(ActiveNode::Error, method, url, "HTTP #{curl.response_code}", opts.merge(:response => response))
        end
      rescue Curl::Err::ConnectionFailedError, Curl::Err::HostResolutionError => e
        fallback(opts) || raise_error(ActiveNode::ConnectionError, method, url, e, opts)
      rescue Curl::Err::CouldntReadError, Curl::Err::RecvError, Curl::Err::GotNothingError => e
        fallback(opts) || raise_error(ActiveNode::ReadError, method, url, e, opts)
      rescue Curl::Err::TimeoutError => e
        raise_error(ActiveNode::TimeoutError, method, url, e, opts.merge(:timeout => timeout))
      end
    end

    def fallback(opts)
      return if opts[:fallback]
      fallback_hosts.each do |host|
        ActiveNode::Base.on_fallback(host, opts)
        server = Server.init(type, host)
        begin
          return server.send(:http, opts.merge(:fallback => true))
        rescue ActiveNode::ConnectionError, ActiveNode::ReadError
        end
      end
      nil
    end

    def raise_error(error_class, method, url, e, opts = {})
      e = "#{e.class}: #{e.message}" unless e.kind_of?(String)

      ActiveNode::Base.after_failure(opts.merge(:message => e, :class => error_class)

      error = error_class.new("#{method} to #{url} failed with #{e}")
      error.cause = opts || {}
      raise error
    end

    def query_string(params)
      if params
        raise ArgumentError, "params must be Hash" unless params.kind_of?(Hash)
        "?" << params.collect do |key, val|
          next if val.nil?
          val = val.join(',') if val.kind_of?(Array)
          "#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
        end.compact.join('&')
      end
    end

    def parse_body(body)
      JSON.load(body) unless body.empty? or body == 'null'
    end
  end
end
