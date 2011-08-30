module ActiveNode::ActiveRecord

  def active_record(table_name, opts={}, &block)
    @ar_class = Class.new(ActiveRecord::Base)
    @ar_class.set_table_name(table_name)
    @ar_class.send(:extend,  ClassMethods)
    @ar_class.send(:include, InstanceMethods)

    if block_given?
      @ar_class.class_eval(&block)
    end
  end

  def active_record_class(type = nil)
    type ? ActiveNode::Base.node_class(type).active_record_class : @ar_class
  end

  module ClassMethods
    def node_id_column(column = nil)
      if column
        @node_id_column = column
      else
        @node_id_column ||= :node_id
      end
    end

    def active_record_class
      self
    end

  end # module ClassMethods

  module InstanceMethods

    def init_lazy_attributes
      lazy_attrs = LazyHash.new { node_coll.layer_data(node_id, :active_record).dup }
      instance_variable_set(:@attributes, lazy_attrs)
      instance_variable_set(:@new_record, false)
    end

  end # module InstanceMethods
end # module ActiveNode::ActiveRecord

class LazyHash
  def initialize(&block)
    @initializer = block
  end

  def method_missing(method, *args)
    @hash ||= @initializer.call
    @hash.send(method, *args)
  end

  def reset
    @hash = nil
  end
end
