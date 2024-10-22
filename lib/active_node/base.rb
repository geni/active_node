class ActiveNode::Base

  def self._load(str)
    node_id = Marshal.load(str)
    raise DumperException, 'invalid format' unless node_id.kind_of?(String)
    node_class(node_id).init(node_id)
  end

  def _dump(ignored)
    Marshal.dump(node_id)
  end

  def ==(other)
    self.class == other.class and node_id == other.node_id
  end

  def eql?(other)
    self.class == other.class and node_id == other.node_id
  end

  def hash
    node_id.hash
  end

  def string_hash
    node_id
  end

  module ClassMethods
    def node_type(type = nil)
      return if self == ActiveNode::Base
      if type
        @node_type = type
      else
        @node_type ||= name.underscore
      end
    end

    def node_id(id_or_node, type = node_type)
      if id_or_node.respond_to?(:node_id)
        id_or_node.node_id
      elsif id_or_node.kind_of?(String)
        id_type, id_number = split_node_id(id_or_node)
        return if type and id_type != type
        "#{id_type}-#{id_number}"
      elsif id_or_node.kind_of?(Integer)
        "#{type}-#{id_or_node}"
      end
    end

    def node_number(node_or_id, type = node_type)
      return node_or_id if node_or_id.kind_of?(Integer)
      type, number = split_node_id(node_id(node_or_id, type))
      return number.to_i if number
    end

    def split_node_id(node_id)
      node_id.to_s.index('-') ? node_id.to_s.split('-', 2) : [node_type, node_id].compact
    end

    def node_class(node_id_or_type)
      split_node_id(node_id_or_type).first.camelize.constantize
    end

    def can_init_node_id?(node_id)
      ActiveNode::Base == self or node_type == split_node_id(node_id).first
    end

    attr_reader :revision

    def at_revision(revision)
      @revision, old_revision = revision, @revision
      yield
    ensure
      @revision = old_revision
    end

    def init(node_id, opts = {})
      return if node_id.nil?
      return node_id if node_id.kind_of?(self) # TODO: ss, write test
      raise ArgumentError, "#{self} cannot init #{node_id}" unless can_init_node_id?(node_id)

      node_id = node_id(node_id)

      if opts[:collection] and not opts[:collection].include?(node_id)
        raise ArgumentError, "node collection does not contain node_id #{node_id}"
      end

      klass = (self == ActiveNode::Base) ? node_class(node_id) : self
      node  = klass.new
      node.instance_variable_set(:@node_id,         node_id)
      node.instance_variable_set(:@node_collection, opts[:collection])
      node.instance_variable_set(:@node_container,  opts[:container])
      node.init_lazy_attributes
      node
    end

    def read_graph(path, params = {})
      ActiveNode.read_graph(ActiveNode.resolve_path(path, node_type), modify_read_params(params))
    end

    def write_graph(path, data, params = {})
      ActiveNode.write_graph(ActiveNode.resolve_path(path, node_type), data, modify_write_params(params)).tap do |result|
        data.meta[:graph_response] = result unless data.nil?
      end
    end

    def bulk_read(params = {}, &block)
      ActiveNode.bulk_read(modify_read_params(params), &block)
    end

    def after_success(opts)
      # Called after an HTTP success response is received from an ActiveNode::Server.
    end

    def after_failure(opts)
      # Called after an HTTP failure response is received from an ActiveNode::Server or
      # when another connection error occurs.
    end

    def on_fallback(host, opts)
      # Called when an error causes us to fallback to a different server.
    end

    def modify_read_params(params)
      # Called to allow modification of params before read_graph dispatches to ActiveNode::Server.
      params
    end

    def modify_write_params(params)
      # Called to allow modification of params before write_graph dispatches to ActiveNode::Server.
      params
    end

    def headers
      # Called from ActiveNode::Server to determine which headers send in the request.
      {}
    end

  end # module ClassMethods

  module InstanceMethods
    def node_id
      @node_id || self.class.node_id(read_attribute(self.class.node_id_column))
    end

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

    def init_lazy_attributes
      # called at end of init
    end

  end # module InstanceMethods
end
