class ActiveNode::Base
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

    attr_reader :revision

    def at_revision(revision)
      @revision, old_revision = revision, @revision
      yield
    ensure
      @revision = old_revision
    end

    def init(node_id, node_coll = nil)
      return if node_id.nil?
      return node_id if node_id.kind_of?(self) # TODO: ss, write test

      node_id = node_id(node_id)

      if node_coll and not node_coll.include?(node_id)
        raise ArgumentError, "node collection does not contain node_id #{node_id}"
      end

      klass = (self == ActiveNode::Base) ? node_class(node_id) : self
      node  = klass.new
      node.instance_variable_set(:@node_id,   node_id)
      node.instance_variable_set(:@node_coll, node_coll)
      node.init_lazy_attributes if node.respond_to?(:init_lazy_attributes)
      node
    end

    def read_graph(path, params = {})
      ActiveNode.read_graph(ActiveNode.resolve_path(path, node_type), modify_read_params(params))
    end

    def write_graph(path, data, params = {})
      ActiveNode.write_graph(ActiveNode.resolve_path(path, node_type), data, modify_write_params(params))
    end

    def bulk_read(params = {}, &block)
      ActiveNode.bulk_read(modify_read_params(params), &block)
    end

    def after_success(opts)
      # Called after an HTTP success response is received from an ActiveNode::Server.
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

    def node_coll
      @node_coll ||= ActiveNode::Collection.new([node_id])
    end

    def meta
      node_coll.meta[node_id]
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
