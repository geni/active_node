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

  def self.read_graph(path, params = {})
    server(:read, path).read(path, params)
  end

  def self.write_graph(path, data, params = {})
    server(:write, path).write(path, data, params)
  end

  def self.bulk_read(params = {}, &block)
    ActiveNode::Server.bulk_read(params, &block)
  end

  def self.init(*args)
    ActiveNode::Base.init(*args)
  end

private

  def self.routes(type)
    @routes ||= {}
    @routes[type] ||= []
  end
end

require 'active_node/base'
require 'active_node/server'
require 'active_node/callbacks'
require 'active_node/attributes'
require 'active_node/collection'
require 'active_node/active_record'
require 'active_node/core_ext'

class Class
  def active_node(opts = {})
    extend  ActiveNode::Base::ClassMethods
    extend  ActiveNode::Callbacks::ClassMethods
    extend  ActiveNode::Collection::ClassMethods
    extend  ActiveNode::Attributes::ClassMethods

    include ActiveNode::Base::InstanceMethods
    include ActiveNode::Callbacks::InstanceMethods
    include ActiveNode::Collection::InstanceMethods
    include ActiveNode::Attributes::InstanceMethods

    if defined?(ActiveRecord::Base) and ancestors.include?(ActiveRecord::Base)
      extend  ActiveNode::ActiveRecord::ClassMethods
      include ActiveNode::ActiveRecord::InstanceMethods
    else
      extend ActiveNode::ActiveRecord
    end
    node_type opts[:node_type]
  end
end

ActiveNode::Base.active_node
