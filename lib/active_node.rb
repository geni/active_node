require 'net/http'
require 'cgi'
require 'json'

$:.unshift(File.dirname(__FILE__))
require 'active_node/base'

module ActiveNode
  DEFAULT_HOST = "localhost:9229"
  METHODS = [:get, :put, :post, :delete]

  class Error   < StandardError; end
  class ConnectionError < Error; end
  class TimeoutError    < Error; end

  def self.server(host)
    @servers ||= {}
    @servers[host] ||= Net::HTTP.new(*host.split(':'))
  end

  module ClassMethods
    def node_type
      @node_type ||= name.downcase
    end

    def node_server
      @node_server ||= ActiveNode.server(node_host)
    end

    def node_host(host = nil)
      if host
        @node_host = host
      else
        @node_host ||= self == ActiveNode::Base ? ActiveNode::DEFAULT_HOST : ActiveNode::Base.node_host
      end
    end

    def load_using(method = nil)
      if method
        @load_using = method
      elsif @load_using.nil?
        @load_using = defined?(ActiveRecord::Base) and kind_of?(ActiveRecord::Base) ? :find_by_node_id : false
      end
      @load_using
    end

    def init(id_or_layers)
      if id_or_layers.kind_of?(Hash)
        node_id = id_or_layers.delete(:id)
        layer_data = {}
        id_or_layers.each do |key, val|
          raise ArgumentError, "layer data must be a Hash; found: #{val.class}" unless val.kind_of?(Hash)
          layer_data[key] = val.clone.freeze
        end
      else
        node_id = id_or_layers
      end
      node = load_using ? send(load_using, node_id) : new
      node.instance_variable_set(:@node_id, node_id)
      node.instance_variable_set(:@layer_data, layer_data || {})
      node
    end

    def query_string(opts)
      if opts
        raise ArgumentError, "opts must be Hash" unless opts.kind_of?(Hash)
        "?" << args.pop.collect do |key, val|
          "#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
        end.join('&')
      end
    end

    METHODS.each do |method|
      put_or_post = [:put, :post].include?(method)
      define_method(method) do |resource, *args|
        resource = "/#{node_type}/#{resource}" unless resource =~ /^\// # support relative and absolute paths
        header   = { 'Content-type' => 'application/json' }

        begin
          if put_or_post
            raise ArgumentError, "wrong number of arguments (#{args.size} for 2)" if args.size > 2
            data = args.first.to_json
            resource << query_string(args.last) if args.size == 2
            response = node_server.send(method, resource, data, header)
          else
            raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" if args.size > 1
            resource << query_string(args.last) if args.size == 1
            response = node_server.send(method, resource, header)
          end

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
    METHODS.each do |method|
      define_method(method) do |resource, *args|
        resource = "/#{node_id}/#{resource}" unless resource =~ /^\//
        self.class.send(method, resource, *args)
      end
    end

    def [](layer)
      layer = layer.to_sym
      @layer_data[layer] ||= get(layer).freeze
    end
  end
end

class Class
  def active_node(opts = {})
    extend  ActiveNode::ClassMethods
    include ActiveNode::InstanceMethods
    node_host  opts[:host]
    load_using opts[:load_using]
  end
end
