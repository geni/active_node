require 'ordered_set'

module ActiveNode
  class Collection
    include Enumerable

    attr_reader :current_revision

    def initialize(ids_or_uri, opts_or_meta = {}, &block)
      if ids_or_uri.kind_of?(String)
        @uri     = ids_or_uri
        @opts    = opts_or_meta.freeze
        @extract = block || lambda {|data| data}
      else
        @node_ids = ids_or_uri.to_ordered_set.freeze
        @meta     = opts_or_meta.freeze
      end
      reset
    end

    def assoc(opts)
      raise ArgumentError, "cannot change opts without uri" if @uri
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

    def layer_data(node_id, layer, revision)
      return unless include?(node_id)
      layer = layer.to_sym
      revision ||= @current_revision

      if @layer_data[node_id].nil? or @layer_data[node_id][revision].nil? or @layer_data[node_id][revision][layer].nil?
        type = ActiveNode::Base.split_node_id(node_id).first
        max_rev = fetch_layer_data(type, [layer], [revision])
        @current_revision = revision = max_rev if revision.nil?
      end
      @layer_data[node_id][revision][layer]
    end

    def layer_revisions(node_id, layer)
      return unless include?(node_id)
      layer = layer.to_sym
      if @layer_revisions[node_id].nil? or @layer_revisions[node_id][layer].nil?
        type = ActiveNode::Base.split_node_id(node_id).first
        fetch_layer_revisions(type, [layer])
      end
      @layer_revisions[node_id][layer]
    end

    def reset(node_id = nil)
      if node_id
        @layer_data.delete(node_id)
        @layer_revisions.delete(node_id)
      else
        @layer_data       = {}
        @layer_revisions  = {}
        @current_revision = nil
      end
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

    def fetch_layer_data(type, layers, revisions)
      if layers.delete(:active_record)
        ActiveNode::Base.active_record_class(type).find_all_by_node_id(node_ids).each do |record|
          node_id = record.node_id
          @layer_data[node_id] ||= {}
          @layer_data[node_id][:active_record] = record.instance_variable_get(:@attributes).freeze
        end
      end
      return if layers.empty?

      ActiveNode.bulk_read do
        revisions.each do |revision|
          node_ids.each do |node_id|
            if ActiveNode::Base.node_id(node_id, type)
              opts = revision ? {:revision => revision, :historical => true} : {}
              ActiveNode.read_graph("/#{node_id}/data/#{layers.join(',')}", opts)
            end
          end
        end
      end.collect do |layer_data|
        node_id  = layer_data['id']
        revision = layer_data['revision']
        @layer_data[node_id] ||= {}
        @layer_data[node_id][revision] ||= {}
        layers.each do |layer|
          data = layer_data[layer.to_s] || {}
          @layer_data[node_id][revision][layer.to_sym] = data.freeze
        end
        revision
      end.max
    end

    def fetch_layer_revisions(type, layers)
      return if layers.empty?

      ActiveNode.bulk_read do
        node_ids.each do |node_id|
          if ActiveNode::Base.node_id(node_id, type)
            ActiveNode.read_graph("/#{node_id}/revisions/#{layers.join(',')}")
          end
        end
      end.collect do |layer_revisions|
        node_id = layer_revisions['id']
        @layer_revisions[node_id] ||= {}
        layers.each do |layer|
          revisions = layer_revisions[layer.to_s]['revisions'] || []
          @layer_revisions[node_id][layer.to_sym] = revisions.freeze
        end
        node_id
      end
    end

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
            ActiveNode::Collection.new("/#{self.node_id}/edges/#{path}", defaults.merge(opts)) do |data|
              {'node_ids' => data[path]['edges'].keys.sort, 'meta' => data[path]['edges']}
            end
          when :incoming then
            ActiveNode::Collection.new("/#{self.node_id}/incoming/#{path}", defaults.merge(opts)) do |data|
              {'node_ids' => data[path]['incoming']}
            end
          when :walk then
            ActiveNode::Collection.new("/#{self.node_id}/#{path}", defaults.merge(opts))
          end
        end
      end

    end # ClassMethods

    module InstanceMethods

      def reset
        @attributes.reset if @attributes
        @node_coll.reset(node_id)
      end

    end # InstanceMethods

  private

    def fetch
      data = @extract.call(ActiveNode.read_graph(@uri, @opts))
      @node_ids = data['node_ids'].to_ordered_set.freeze
      @meta     = data['meta'] || {}
    end

  end
end
