require 'active_node/attributes'
require 'active_node/collection'
require 'active_node/active_record'

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

  def self.with_routes(routes = {})
    old_routes = @routes
    @routes = routes
    yield
  ensure
    @routes = old_routes
  end

  def self.read_graph(path, opts = {})
    path   = "/#{path}" unless absolute_path?(path)
    server = ActiveNode.server(:read, path)

    if @bulk_read
      server.enqueue_read(path, opts)
    else
      server.read(path, opts)
    end
  end

  def self.write_graph(path, data, opts = {})
    raise Error, 'cannot write inside a bulk_read block' if @bulk_read

    path   = "/#{path}" unless absolute_path?(path)
    server = ActiveNode.server(:write, path)
    server.write(path, data, opts)
  end

  def self.bulk_read(opts = {})
    raise Error, 'cannot nest calls to bulk_read' if @bulk_read
    @bulk_read = true
    yield
    ActiveNode::Server.bulk_read(opts)
  ensure
    @bulk_read = nil
  end

  def self.resolve_path(path, base)
    absolute_path?(path) ? path : "/#{base}/#{path}" # support relative and absolute paths
  end

  def self.init(*args)
    ActiveNode::Base.init(*args)
  end

private

  def self.absolute_path?(path)
    path[0] == ?/
  end

  def self.routes(type)
    @routes ||= {}
    @routes[type] ||= []
  end

  module ClassMethods
    def node_type(type = nil)
      if type
        @node_type = type
      elsif self != ActiveNode::Base
        @node_type ||= name.underscore
      end
    end

    def node_id(id_or_node, type = node_type)
      if id_or_node.respond_to?(:node_id)
        id_or_node.node_id
      elsif id_or_node.kind_of?(String)
        id_type = split_node_id(id_or_node).first
        return if type and id_type != type
        id_or_node
      elsif id_or_node.kind_of?(Integer)
        "#{type}-#{id_or_node}"
      end
    end

    def node_number(node_or_id, type = node_type)
      return node_or_id if node_or_id.kind_of?(Integer)
      split_node_id(node_id(node_or_id, type)).last.to_i
    end

    def split_node_id(node_id)
      node_id.split('-', 2)
    end

    def node_class(node_id_or_type)
      split_node_id(node_id_or_type).first.camelize.constantize
    end

    def init(node_id, node_coll = nil)
      return if node_id.nil?
      return node_id if node_id.kind_of?(self) # TODO: ss, write test

      node_coll ||= ActiveNode::Collection.new([node_id])
      raise ArgumentError, "node collection does not contain node_id #{node_id}" unless node_coll.include?(node_id)

      klass = (self == ActiveNode::Base) ? node_class(node_id) : self
      node  = klass.new
      node.instance_variable_set(:@node_id,   node_id)
      node.instance_variable_set(:@node_coll, node_coll)
      node.init_lazy_attributes if node.respond_to?(:init_lazy_attributes)
      node
    end

    def read_graph(path, opts = {})
      path = ActiveNode.resolve_path(path, node_type)
      ActiveNode.read_graph(path, opts)
    end

    def write_graph(path, data, opts = {})
      path = ActiveNode.resolve_path(path, node_type)
      ActiveNode.write_graph(path, data, opts)
    end
  end # module ClassMethods

  module InstanceMethods
    def node_id
      @node_id || self.class.node_id(read_attribute(self.class.node_id_column))
    end

    def meta
      @node_coll.meta[node_id]
    end
    alias edge meta

    def node_number
      self.class.node_number(node_id)
    end

    def node_type
      self.class.node_type
    end

    def read_graph(path = 'node', opts = {})
      (opts, path) = [path, 'node'] if path.kind_of?(Hash)
      path = ActiveNode.resolve_path(path, node_id)
      self.class.read_graph(path, opts)
    end

    def write_graph(path, data, opts = {})
      path = ActiveNode.resolve_path(path, node_id)
      self.class.write_graph(path, data, opts)
    end
  end # module InstanceMethods
end

$:.unshift(File.dirname(__FILE__))
require 'active_node/base'
require 'active_node/server'

class String
  # Add underscore and camelize methods if they aren't there. Copied from ActiveSupport::Inflector
  def underscore
    self.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").downcase
  end unless instance_methods.include?('underscore')

  def camelize
    gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
  end unless instance_methods.include?('camelize')

  def constantize
    constant = Object
    split('::').each do |name|
      constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
    end
    constant
  end unless instance_methods.include?('constantize')
end

class Class
  def active_node(opts = {})
    extend  ActiveNode::ClassMethods
    extend  ActiveNode::Collection::ClassMethods
    include ActiveNode::InstanceMethods
    if defined?(ActiveRecord::Base) and ancestors.include?(ActiveRecord::Base)
      extend  ActiveNode::ActiveRecord::ClassMethods
      include ActiveNode::ActiveRecord::InstanceMethods
    end
    node_type opts[:node_type]
  end
end

class LazyHash
  def initialize(&block)
    @initializer = block
  end

  def method_missing(method, *args)
    @hash ||= @initializer.call
    @hash.send(method, *args)
  end

  def reset
    @hash = nil
  end

end
