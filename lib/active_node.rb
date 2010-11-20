module ActiveNode
  class Error < StandardError
    attr_accessor :cause
  end
  class ConnectionError < Error; end
  class TimeoutError    < Error; end

  def self.server(type, path)
    host = nil
    routes(type).each do |pattern, route|
      match = pattern.match(path)
      host  = route.kind_of?(Proc) ? route.call(match.values_at(1..-1)) : route if match
      break if host
    end

    @servers ||= {}
    @servers[host] ||= Server.new(host)
  end

  # inspired by Sinatra (sinatrarb.com)
  def self.route(*args, &block) # [type], [pattern], host | &dynamic_route
    if block_given?
      # dynamic route
      raise ArgumentError, "wrong number of arguments (#{args.size} for 2)" if args.size > 2
      route = block
    else
      # static route
      raise ArgumentError, "wrong number of arguments (#{args.size} for 3)" if args.size > 3
      raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" if args.size < 1
      route = args.pop
    end

    if args.size == 2
      type, path = args
    elsif args.first.kind_of?(Symbol)
      type = args.first
    else
      path = args.first
    end
    path ||= '.*'
    pattern = Regexp.new(path.to_s.gsub("*","(.*?)"))

    routes(:write) << [pattern, route] if type.nil? or type == :write
    routes(:read)  << [pattern, route] if type.nil? or type == :read
  end

  def self.read_graph(path, opts = nil)
    path   = "/#{path}" unless absolute_path?(path)
    server = ActiveNode.server(:read, path)
    server.read(path, opts)
  end

  def self.write_graph(path, data, opts = nil)
    path   = "/#{path}" unless absolute_path?(path)
    server = ActiveNode.server(:write, path)
    server.write(path, data, opts)
  end

  def self.resolve_path(path, base)
    absolute_path?(path) ? path : "/#{base}/#{path}" # support relative and absolute paths
  end
  
private

  def self.absolute_path?(path)
    path.mb_chars.first == '/'
  end

  def self.routes(type)
    @routes ||= {}
    @routes[type] ||= []
  end

  module ClassMethods
    def node_type(type = nil)
      if type
        @node_type = type
      else
        @node_type ||= name.underscore
      end
    end

    def load_using(method = nil)
      if method
        @load_using = method
      elsif @load_using.nil?
        isa_ar = defined?(ActiveRecord::Base) and ancestors.include?(ActiveRecord::Base)
        @load_using = isa_ar ? :find_by_node_id : false
      end
      @load_using
    end

    def init(id_or_layers)
      if id_or_layers.kind_of?(Hash)
        node_id = id_or_layers.delete(:id) || id_or_layers.delete('id')
        layer_data = {}
        id_or_layers.each do |key, val|
          raise ArgumentError, "layer data must be a Hash; found: #{val.class}" unless val.kind_of?(Hash)
          layer_data[key.to_sym] = val.clone.freeze
        end
      else
        node_id = id_or_layers
      end
      node = load_using ? send(load_using, node_id) : new
      node.instance_variable_set(:@node_id, node_id)
      node.instance_variable_set(:@layer_data, layer_data || {})
      node
    end

    def read_graph(path, opts = nil)
      path = ActiveNode.resolve_path(path, node_type)
      ActiveNode.read_graph(path, opts)
    end

    def write_graph(path, data, opts = nil)
      path = ActiveNode.resolve_path(path, node_type)
      ActiveNode.write_graph(path, data, opts)
    end
  end

  module InstanceMethods
    def read_graph(path, opts = nil)
      path = ActiveNode.resolve_path(path, node_id)
      self.class.read_graph(path, opts)
    end

    def write_graph(path, data, opts = nil)
      path = ActiveNode.resolve_path(path, node_id)
      self.class.write_graph(path, data, opts)
    end

    def layer_data
      @layer_data ||= LayerData.new(self)
    end
  end

  class LayerData
    def initialize(node)
      @node = node
      @data = {}
    end

    def [](layer)
      layer = layer.to_sym
      @data[layer] ||= node.get(layer).freeze
    end

    def keys
      @data.keys
    end

    def values
      @data.values
    end
  end
end

$:.unshift(File.dirname(__FILE__))
require 'active_node/base'
require 'active_node/server'

unless String.instance_methods.include?('underscore')
  class String
    # Add underscore method if it isn't there. Copied from ActiveSupport::Inflector
    def underscore
      self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
  end
end

class Class
  def active_node(opts = {})
    extend  ActiveNode::ClassMethods
    include ActiveNode::InstanceMethods
    load_using opts[:load_using]
    node_type  opts[:node_type]
  end
end
