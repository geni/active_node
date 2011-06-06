module ActiveNode
  class Base
    extend  ClassMethods
    include InstanceMethods

    extend  Attributes::ClassMethods
    include Attributes::InstanceMethods

    extend  Collection::ClassMethods
    include Collection::InstanceMethods

    attr_reader :node_id
  end
end
