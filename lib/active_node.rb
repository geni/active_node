module ActiveNode
  class Error < StandardError
    attr_accessor :cause
  end
  class ConnectionError < Error; end
  class TimeoutError    < Error; end
  class ReadError       < Error; end

  def self.server(type, path)
    host = nil
    routes(type).each do |pattern, route|
      match = pattern.match(path)
      host  = route.kind_of?(Proc) ? route.call(*match.values_at(1..-1)) : route if match
      break if host
    end
    host = host.choice if host.respond_to?(:choice) # choose a random server

    Server.init(type, host)
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
    path ||= '*'
    if path.kind_of?(Regexp)
      pattern = path
    else
      pattern = Regexp.new('^' + path.to_s.gsub("*","(.*?)") + '.*?$')
    end
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

  def self.init(*args)
    ActiveNode::Base.init(*args)
  end

  def self.resolve_path(path, base = nil)
    absolute_path?(path) ? path : ['', base, path].compact.join('/') # support relative and absolute paths
  end

  def self.fallback_hosts(type, hosts = nil)
    @fallback_hosts ||= {}
    @fallback_hosts[type] = hosts if hosts
    @fallback_hosts[type] || []
  end

protected 

  def self.read_graph(path, params = {})
    path = resolve_path(path)
    server(:read, path).read(path, params)
  end

  def self.write_graph(path, data, params = {})
    path = resolve_path(path)
    server(:write, path).write(path, data, params)
  end

  def self.bulk_read(params = {}, &block)
    ActiveNode::Server.bulk_read(params, &block)
  end

private

  def self.absolute_path?(path)
    path[0] == ?/
  end

  def self.routes(type)
    @routes ||= {}
    @routes[type] ||= []
  end
end

require 'active_node/base'
require 'active_node/server'
require 'active_node/schema'
require 'active_node/writers'
require 'active_node/containment'
require 'active_node/attributes'
require 'active_node/collection'
require 'active_node/active_record'
require 'active_node/core_ext'
require 'active_node/utils'

class Class
  def active_node(opts = {})
    extend  ActiveNode::Base::ClassMethods
    extend  ActiveNode::Collection::ClassMethods

    include ActiveNode::Base::InstanceMethods
    include ActiveNode::Collection::InstanceMethods

    extend  ActiveNode::Schema::ClassMethods
    include ActiveNode::Schema::InstanceMethods

    extend  ActiveNode::Writers::ClassMethods

    if opts[:attributes]
      extend  ActiveNode::Attributes::ClassMethods
      # must come after Attributes because update! is overridden for contained nodes
      extend  ActiveNode::Containment::ClassMethods

      include ActiveNode::Attributes::InstanceMethods
      # must come after Attributes because update! is overridden for contained nodes
      include ActiveNode::Containment::InstanceMethods
    end

    if defined?(ActiveRecord::Base) and ancestors.include?(ActiveRecord::Base)
      extend  ActiveNode::ActiveRecord::ClassMethods
      include ActiveNode::ActiveRecord::InstanceMethods
    else
      extend ActiveNode::ActiveRecord
    end
    node_type opts[:node_type]
  end
end

ActiveNode::Base.active_node(:attributes => true)

class Hash
  def meta
    @_meta ||= {}
  end

  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  def deep_symbolize_keys!
    values.each do |val|
      val.deep_symbolize_keys! if val.is_a?(Hash)
    end
    symbolize_keys!
  end
end
