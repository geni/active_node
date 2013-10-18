module ActiveNode::ActiveRecordCompatibility
  def active_record_compatibility
    extend ClassMethods
    include InstanceMethods
  end

  module ClassMethods
    def find(first, *args)
      if first.kind_of?(Integer)
        init(id)
      elsif first.kind_of?(Array)
        ActiveNode::Collection.new(first.map {|x| node_id(x)}).to_a
      else
        raise ActiveNode::Error, "find with args (#{args}) not supported"
      end
    end

    def base_class(klass = self)
      if klass.superclass == ActiveNode::Base
        klass
      elsif klass.superclass.nil?
        raise ActiveNode::Error, "#{name} doesn't belong in a hierarchy descending from ActiveNode"
      else
        base_class(klass.superclass)
      end
    end
  end

  module InstanceMethods
    def id
      node_number
    end

    def destroyed?
      false
    end

    def new_record?
      false
    end
  end
end
