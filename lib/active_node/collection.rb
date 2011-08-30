require 'ordered_set'
require 'deep_hash'

module ActiveNode
  class Collection
    include Enumerable

    attr_reader :current_revision

    def self.empty
      new([])
    end

    def initialize(ids_or_uri, opts_or_meta = {}, &block)
      if ids_or_uri.kind_of?(String)
        @uri     = ids_or_uri
        @opts    = opts_or_meta.freeze
        @extract = block || lambda {|data| data}
      else
        @node_ids = ids_or_uri.to_ordered_set.freeze
        @meta     = opts_or_meta.freeze
      end
      @nodes = {}
      clear_cache
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

    def layer_data(node_id, layer, revision=nil)
      return unless include?(node_id)
      layer = layer.to_sym
      revision ||= @current_revision

      if @layer_data[node_id][layer][revision].nil?
        type = ActiveNode::Base.split_node_id(node_id).first
        max_rev = fetch_layer_data(type, [layer], [revision])
        @current_revision = revision = max_rev if revision.nil?
      end
      @layer_data[node_id][layer][revision]
    end

    def layer_revisions(node_id, layer)
      return unless include?(node_id)
      layer = layer.to_sym
      if @layer_revisions[node_id][layer].nil?
        type = ActiveNode::Base.split_node_id(node_id).first
        fetch_layer_revisions(type, [layer])
      end
      @layer_revisions[node_id][layer]
    end

    def reset_current_revision
      @current_revision = nil
    end

    def clear_cache
      @layer_data      = Hash.deep(2)
      @layer_revisions = Hash.deep(1)
    end

    def each
      node_ids.each do |node_id|
        yield @nodes[node_id] ||= ActiveNode.init(node_id, :collection => self)
      end
    end

    def size
      node_ids.size
    end

    def [](index)
      if index.kind_of?(String)
        raise ArgumentError, "#{index} not in collection" unless node_ids.include?(index)
        node_id = index
      elsif index.kind_of?(Integer)
        node_id = node_ids[index]
      else
        raise ArgumentError, "String or Integer required as index for []"
      end
      @nodes[node_id] ||= ActiveNode.init(node_id, :collection => self)
    end

    def first
      self[0]
    end

    def last
      self[-1]
    end

    def include?(node_or_id)
      node_ids.include?(ActiveNode::Base.node_id(node_or_id))
    end

    def empty?
      node_ids.empty?
    end

    def fetch_layer_data(type, layers, revisions)
      if layers.delete(:active_record)
        record_class = ActiveNode::Base.ar_class(type)
        record_class.find_all_by_node_id(node_ids).each do |record|
          node_id = record.node_id
          @layer_data[node_id][:active_record][nil] = record.instance_variable_get(:@attributes).freeze
        end
        node_ids.each do |node_id|
          @layer_data[node_id][:active_record][nil] ||= record_class.new.instance_variable_get(:@attributes).freeze
        end
      end
      return if layers.empty?

      ActiveNode.bulk_read do
        revisions.each do |revision|
          node_ids.each do |node_id|
            if ActiveNode::Base.node_id(node_id, type)
              opts = Collection.revision_opts(revision)
              ActiveNode.read_graph("/#{node_id}/data/#{layers.join(',')}", opts)
            end
          end
        end
      end.collect do |layer_data|
        node_id  = layer_data['id']
        revision = layer_data['revision']
        layers.each do |layer|
          data = layer_data[layer.to_s] || {}
          @layer_data[node_id][layer.to_sym][revision] = data.freeze
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
        layers.each do |layer|
          revisions = layer_revisions[layer.to_s]['revisions'] || []
          @layer_revisions[node_id][layer.to_sym] = revisions.freeze
        end
        node_id
      end
    end

    def self.revision_opts(revision)
      revision ? {:revision => revision, :historical => true} : {}
    end

    module ClassMethods

      ASSOCIATIONS = [:attr, :edge, :edges, :incoming, :walk]
      def has(name, opts = {})
        associations = ASSOCIATIONS.select {|k| opts[k]}.compact
        raise ArgumentError, "only one of #{ASSOCIATIONS.join(', ')} required in has" if associations.size > 1

        type      = associations.first || :attr
        path      = opts.delete(type)
        path      = path.to_s.gsub(/_/, '-') unless :attr == type
        predicate = opts.delete(:predicate)
        count     = opts.delete(:count)
        defaults  = opts.freeze

        define_method(name) do |*args|
          opts = defaults.merge(Utils.extract_options(args))

          has_cache[name][opts] ||= case type

            when :attr then
              attr = get_attr(path || name, defaults)
              if attr.is_a?(Array)
                ActiveNode::Collection.new(attr)
              else
                ActiveNode.init(attr)
              end

            when :edges, :edge then
              ActiveNode::Collection.new("/#{node_id}/edges/#{path}", opts) do |data|
                data[path] ||= {'edges' => {}}
                {'node_ids' => data[path]['edges'].keys.sort, 'meta' => data[path]['edges']}
              end

            when :incoming then
              ActiveNode::Collection.new("/#{node_id}/incoming/#{path}", opts) do |data|
                data[path] ||= {'incoming' => []}
                {'node_ids' => data[path]['incoming']}
              end

            when :walk then
              ActiveNode::Collection.new("/#{node_id}/#{path}", opts)

          end

          if :edge == type
            has_cache[name][opts].first
          else
            has_cache[name][opts]
          end
        end

        singular = name.to_s.sub(/s$/,'')
        if [:edges, :walk, :incoming].include?(type)
          count ||= "#{singular}_count"
          define_method(count) do |*args|
            opts = defaults.merge(Utils.extract_options(args)).merge!(:count => true)
            has_cache[count][opts] ||= if (type == :walk)
              ActiveNode.read_graph("/#{node_id}/#{type}/#{path}", opts)['count']
            else
              ActiveNode.read_graph("/#{node_id}/#{type}/#{path}", opts)[path][type.to_s]
            end
          end
        end

        if predicate
          predicate = singular + '?' if predicate == true
          define_method(predicate) do |other|
            if :edge == type
              ActiveNode::Base.node_id(send(name)) == ActiveNode::Base.node_id(other)
            else
              send(name).include?(other)
            end
          end
        end
      end

    end # ClassMethods

    module InstanceMethods
      def node_collection
        @node_collection ||= ActiveNode::Collection.new([node_id])
      end

      def meta
        node_collection.meta[node_id]
      end
      alias edge meta

      def reset
        @attributes.clear if @attributes
        @_has_cache = nil
        @ar_instance = nil
        node_collection.reset_current_revision
      end

      def layer_data(layer, revision = self.class.revision)
        node_collection.layer_data(node_id, layer, revision)
      end

      def fetch_layer_data(layers, revisions)
        node_collection.fetch_layer_data(node_type, layers, revisions)
      end

      def revisions(layers)
        return revisions([layers])[layers] unless layers.kind_of?(Array)
        revisions = {}
        layers.each do |layer|
          revisions[layer] = node_collection.layer_revisions(node_id, layer)
        end
        revisions
      end

      def fetch_layer_revisions(layers)
        node_collection.fetch_layer_revisions(node_type, layers)
      end

    private

      def has_cache
        @_has_cache ||= Hash.deep(1)
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
