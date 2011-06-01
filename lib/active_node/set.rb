module ActiveNode
  class Set
    include Enumerable

    attr_reader :node_ids

    def initialize(node_ids)
      @node_ids   = node_ids.clone.freeze
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
        ActiveNode.init(node_id, self)
      end
    end
  end
end
