class ActiveNode::Base
  extend  ActiveNode::ClassMethods
  include ActiveNode::InstanceMethods
  attr_reader :node_id
end
