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
      @layer_data[node_id][layer]
    end

    def fetch_layer_data(type, layers)
      ActiveNode.bulk_read do
        node_ids.each do |node_id|
          if ActiveNode.node_id(node_id, type)
            ActiveNode.read_graph("/#{node_id}/node/#{layers.join(',')}")
          end
        end
      end.collect do |layer_data|
        node_id = layer_data.delete("id")
        @layer_data[node_id] ||= {}
        layer_data.each do |layer, data|
          @layer_data[node_id][layer] = data.freeze
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
      node_ids.include?(ActiveNode.node_id(node_or_id))
    end
  end
end
