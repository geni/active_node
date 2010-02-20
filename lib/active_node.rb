require 'net/http'
require 'cgi'
require 'json'

$:.unshift(File.dirname(__FILE__))
require 'active_node/base'

module ActiveNode
  METHODS = [:get, :put, :post, :delete]

  class Error   < StandardError; end
  class ConnectionError < Error; end
  class TimeoutError    < Error; end

  def self.server(host)
    @servers ||= {}
    @servers[host] ||= Net::HTTP.new(*host.split(':'))
  end

  module ClassMethods
    def node_type(type = nil)
      if type
        @node_type = type
      else
        @node_type ||= name.downcase
      end
    end

    def node_host(host = nil)
      if host
        @node_host = host
      else
        @node_host ||= "localhost:9229"
      end
    end

    def node_server
      @node_server ||= ActiveNode.server(node_host)
    end

    def new(*args)
      if args.size == 1 and args.first.is_a?(String) and args.first =~ /^(\w)\/(\d)$/
        raise "invalid node type" unless $1 == node_type
        model = respond_to?(:find) ? find($2.to_i) : super()
        model.instance_variable_set(:@node_id, args.first)
      else
        model = super
        model.instance_variable_set(:@node_id, "#{node_type}:#{model.id}")
      end
      model
    end

    METHODS.each do |method|
      define_method(method) do |resource, *args|
        resource = "/#{node_type}/#{resource}" unless resource =~ /^\//
        put_or_post = [:put, :post].include?(method)
        args << '' if args.empty? and put_or_post

        begin
          if args.first.kind_of?(Hash)
            if put_or_post
              args.unshift(args.shift.to_json)
            else
              resource << "?" << args.shift.collect do |key, val|
                "#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
              end.join('&')
            end
          end

          response = node_server.send(method, resource, *args)
          if response.code =~ /\A2\d{2}\z/
            body = response.body
            return nil if body.empty? or body == 'null'
            return JSON.load(body)
          end
          raise ActiveNode::Error, "#{method} to http://#{host}#{resource} failed with HTTP #{response.code}"
        rescue Errno::ECONNREFUSED => e
          raise ActiveNode::ConnectionError, "connection refused on #{method} to http://#{host}#{resource}"
        rescue TimeoutError => e
          raise ActiveNode::ConnectionError, "timeout on #{method} to http://#{host}#{resource}"
        end
      end
    end
  end

  module InstanceMethods
    attr_accessor :node_id

    METHODS.each do |method|
      define_method(method) do |resource, *args|
        resource = "/#{node_id}/#{resource}" unless resource =~ /^\//
        self.class.send(method, resource, *args)
      end
    end
  end
end

class Class
  def active_node(opts = {})
    extend  ActiveNode::ClassMethods
    include ActiveNode::InstanceMethods
    node_host opts[:host]
    node_type opts[:type]
  end
end
