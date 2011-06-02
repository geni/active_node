require 'ordered_set'

module ActiveNode
  class Set
    include Enumerable

    attr_reader :node_ids

    def initialize(node_ids)
      @node_ids   = node_ids.to_ordered_set.freeze
      @layer_data = {}
    end

    def layer_data(node_id, layer)
      return unless include?(node_id)
      layer = layer.to_sym
      if @layer_data[node_id].nil? or @layer_data[node_id][layer].nil?
        type = ActiveNode::Base.split_node_id(node_id).first
        fetch_layer_data(type, [layer])
      end
      @layer_data[node_id][layer]
    end

    def fetch_layer_data(type, layers)
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
            ActiveNode.read_graph("/#{node_id}/node/#{layers.join(',')}")
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

    def each
      node_ids.each do |node_id|
        yield ActiveNode.init(node_id, self)
      end
    end

    def include?(node_or_id)
      node_ids.include?(ActiveNode::Base.node_id(node_or_id))
    end
  end
end
