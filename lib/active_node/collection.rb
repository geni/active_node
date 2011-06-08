require 'ordered_set'

module ActiveNode
  class Collection
    include Enumerable

    def initialize(ids_or_uri, opts_or_meta = {}, &block)
      if ids_or_uri.kind_of?(String)
        @uri     = ids_or_uri
        @opts    = opts_or_meta.freeze
        @extract = block || lambda {|data| data}
      else
        @node_ids = ids_or_uri.to_ordered_set.freeze
        @meta     = opts_or_meta.freeze
      end
      @layer_data = {}
    end

    def assoc(opts)
      raise ArgumentError, "cannot change opts without uri" if @uri
      # TODO: share layer with new instance
      self.class.new(@uri, @opts.merge(opts))
    end

    def node_ids
      fetch unless @node_ids
      @node_ids
    end

    def meta
      fetch unless @meta
      @meta
    end

    def layer_data(node_id, layer)
      # TODO: lock layer data to a specific revision
      return unless include?(node_id)
      layer = layer.to_sym
      if @layer_data[node_id].nil? or @layer_data[node_id][layer].nil?
        type = ActiveNode::Base.split_node_id(node_id).first
        fetch_layers(type, [layer])
      end
      @layer_data[node_id][layer]
    end

    def reset(node_id)
      @layer_data.delete(node_id)
    end

    def each
      node_ids.each do |node_id|
        yield ActiveNode.init(node_id, self)
      end
    end

    def [](index)
      if index.kind_of?(String) and node_ids.include?(index)
        ActiveNode.init(index, self)
      elsif index.kind_of?(Integer)
        ActiveNode.init(node_ids[index], self)
      else
        raise ArgumentError, "String or Integer required as index for []"
      end
    end

    def include?(node_or_id)
      node_ids.include?(ActiveNode::Base.node_id(node_or_id))
    end

    module InstanceMethods

      def layer_data(layer)
        @node_coll.layer_data(node_id, layer)
      end

      def reset
        @attributes.reset if @attributes
        @node_coll.reset(node_id)
      end

    end # InstanceMethods

    module ClassMethods

      ASSOCIATIONS = [:edges, :incoming, :walk]
      def has(name, opts = {})
        associations = ASSOCIATIONS.select {|k| opts[k]}.compact
        raise ArgumentError, "exactly one of #{ASSOCIATIONS.join(', ')} required in has_many" unless associations.size == 1

        type     = associations.first
        path     = opts.delete(type).to_s.gsub(/_/, '-')
        defaults = opts.freeze
        cache    = {}

        define_method(name) do |*args|
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" if args.size > 1
          opts = args.first || {}

          cache[opts] ||= case type
          when :edges then
            ActiveNode::Collection.new("/#{self.node_id}/edges/#{path}", defaults.merge(opts))
          when :incoming then
            ActiveNode::Collection.new("/#{self.node_id}/incoming/#{path}", defaults.merge(opts))
          when :walk then
            ActiveNode::Collection.new("/#{self.node_id}/#{path}", defaults.merge(opts))
          end
        end
      end

    end # ClassMethods

    def fetch_layers(type, layers)
      if layers.delete(:active_record)
        ActiveNode::Base.node_class(type).find_all_by_node_id(node_ids).each do |record|
          node_id = record.node_id
          @layer_data[node_id] ||= {}
          @layer_data[node_id][:active_record] = record.instance_variable_get(:@attributes).freeze
        end
      end
      return if layers.empty?

      ActiveNode.bulk_read do
        node_ids.each do |node_id|
          if ActiveNode::Base.node_id(node_id, type)
            ActiveNode.read_graph("/#{node_id}/data/#{layers.join(',')}")
          end
        end
      end.collect do |layer_data|
        node_id = layer_data.delete("id")
        @layer_data[node_id] ||= {}
        layers.each do |layer|
          data = layer_data[layer.to_s] || {}
          @layer_data[node_id][layer.to_sym] = data.freeze
        end
        node_id
      end
    end

  private

    def fetch
      data = @extract.call(ActiveNode.read_graph(@uri, @opts))
      @node_ids = data['node_ids'].to_ordered_set.freeze
      @meta     = data['meta'] || {}
    end
  end
end
