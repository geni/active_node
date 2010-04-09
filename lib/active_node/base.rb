module ActiveNode
  class Base
    extend  ActiveNode::ClassMethods
    include ActiveNode::InstanceMethods
    attr_reader :node_id
  end
end
