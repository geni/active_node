require 'ordered_set'
require 'deep_hash'

module ActiveNode
  class Collection
    include Enumerable

    attr_reader :current_revision

    def self.empty
      new([])
    end

    def initialize(uri_or_ids, params_or_edges = {}, &block)
      if uri_or_ids.kind_of?(String)
        @uri     = uri_or_ids
        @params  = params_or_edges.freeze
        @extract = block || lambda {|response| response}
      else
        # OrderedSet.map barfs if uri_or_ids is already frozen (un-dike and run tests for more info)
        @node_ids  = uri_or_ids.to_ordered_set#.freeze
        @count     = @node_ids.count
        @edge_data = params_or_edges.freeze
      end
      @nodes = {}
      clear_cache
    end

    def self.init(node_class, ids)
      new(ids.map {|id| node_class.node_id(id)})
    end

    def assoc_params(params)
      raise ArgumentError, "cannot change params without uri" unless @uri
      self.class.new(@uri, @params.merge(params), &@extract)
    end

    def limit(limit, opts = {})
      offset = if opts[:page]
        opts[:page] * limit
      else
        opts[:offset] || 0
      end

      if @node_ids
        self.class.new(@node_ids.limit(limit, offset), @edge_data)
      else
        assoc_params(:limit => limit, :offset => offset)
      end
    end

    def node_ids(node_type=nil)
      fetch unless @node_ids
      node_type.blank? ? @node_ids : @node_ids.select {|id| 0 == id.index(node_type)}
    end

    def self.node_ids(ids_or_nodes, type = nil)
      if ids_or_nodes.respond_to?(:node_ids)
        ids_or_nodes.node_ids
      else
        ids_or_nodes.map do |node_or_id|
          ActiveNode::Base.node_id(node_or_id, type)
        end
      end
    end

    def edge_data
      fetch unless @edge_data
      @edge_data
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

    def each(node_type=nil)
      node_ids(node_type).each do |node_id|
        yield @nodes[node_id] ||= ActiveNode.init(node_id, :collection => self)
      end
    end

    def +(other)
      other_ids = self.class.node_ids(other)
      new_edges = other.respond_to?(:edge_data) ? other.edge_data.merge(edge_data) : edge_data

      self.class.new(node_ids + other_ids, new_edges)
    end

    def -(other)
      other_ids  = self.class.node_ids(other)
      self.class.new(node_ids - other_ids, edge_data)
    end

    def &(other)
      other_ids = self.class.node_ids(other)
      self.class.new(node_ids & other_ids, edge_data)
    end

    def size
      node_ids.size
    end
    alias length size

    def count
      fetch unless @count
      @count
    end

    def [](index)
      if index.kind_of?(String)
        return nil unless node_ids.include?(index)
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
        ids = node_ids.collect {|id| ActiveNode::Base.node_number(id, type)}.compact
        record_class.find_all_by_node_id(ids).each do |record|
          node_id = record.node_id
          @layer_data[node_id][:active_record][nil] = record.instance_variable_get(:@attributes).freeze
        end
        node_ids.each do |node_id|
          @layer_data[node_id][:active_record][nil] ||= record_class.new.instance_variable_get(:@attributes).freeze
        end
      end
      return if layers.empty?

      ActiveNode::Base.bulk_read do
        revisions.each do |revision|
          node_ids.each do |node_id|
            if ActiveNode::Base.node_id(node_id, type)
              opts = Collection.revision_opts(revision)
              ActiveNode::Base.read_graph("/#{node_id}/data/#{layers.join(',')}", opts)
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

      ActiveNode::Base.bulk_read do
        node_ids.each do |node_id|
          if ActiveNode::Base.node_id(node_id, type)
            ActiveNode::Base.read_graph("/#{node_id}/revisions/#{layers.join(',')}")
          end
        end
      end.collect do |layer_revisions|
        node_id = layer_revisions['id']
        layers.each do |layer|
          revisions = layer_revisions[layer.to_s] || {}
          revisions = revisions['revisions'] || []
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
          Utils.ensure_arity(args, 1)
          params = defaults.merge(args.first || {})

          has_cache[name][params] ||= case type
          when :attr then
            attr = get_attr(path || name, defaults)
            if attr.is_a?(Array)
              ActiveNode::Collection.new(attr)
            else
              ActiveNode.init(attr)
            end
          when :edges, :edge then
            ActiveNode::Collection.new("/#{node_id}/edges/#{path}", params) do |response|
              response[path] ||= {'edges' => {}}
              {'node_ids' => response[path]['edges'].keys.sort, 'data' => response[path]['edges']}
            end
          when :incoming then
            ActiveNode::Collection.new("/#{node_id}/incoming/#{path}", params) do |response|
              response[path] ||= {'incoming' => []}
              {'node_ids' => response[path]['incoming']}
            end
          when :walk then
            ActiveNode::Collection.new("/#{node_id}/#{path}", params)
          end

          if :edge == type
            has_cache[name][params].first
          else
            has_cache[name][params]
          end
        end

        singular = name.to_s.sub(/s$/,'')
        if [:edges, :walk, :incoming].include?(type)
          count ||= "#{singular}_count"
          define_method(count) do |*args|
            Utils.ensure_arity(args, 1)
            opts = defaults.merge(args.first || {}).merge!(:count => true)
            has_cache[count][opts] ||= if (type == :walk)
              ActiveNode::Base.read_graph("/#{node_id}/#{path}", opts)['count']
            else
              ActiveNode::Base.read_graph("/#{node_id}/#{type}/#{path}", opts)[path][type.to_s]
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

      def edge_data
        node_collection.edge_data[node_id]
      end

      def reset
        @attributes.clear if @attributes
        @_has_cache = nil
        @ar_instance = nil
        node_collection.reset_current_revision
        super rescue nil
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
        layers.flatten.each do |layer|
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
      return unless @uri

      response = @extract.call(ActiveNode::Base.read_graph(@uri, @params))
      @node_ids  = (response['node_ids'] || response['ids'] || []).to_ordered_set.freeze
      @count     = response['count']
      @edge_data = (response['data'] || {}).freeze
    end

  end
end
