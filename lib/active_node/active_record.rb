module ActiveNode::ActiveRecord

  def active_record(table_name, opts={}, &block)
    @ar_class = Class.new(ActiveRecord::Base)
    @ar_class.set_table_name(table_name)
    @ar_class.send(:extend,  ClassMethods)
    @ar_class.send(:include, InstanceMethods)

    extend NodeClassMethods

    if block_given?
      @ar_class.class_eval(&block)
    end
  end

  module NodeClassMethods
    def active_record_class(type = nil)
      type ? ActiveNode::Base.node_class(type).active_record_class : @ar_class
    end
  end

  module ClassMethods
    def node_id_column(column = nil)
      if column
        @node_id_column = column
      else
        @node_id_column ||= :node_id
      end
    end

    def find_by_node_id(node_id)
      first(:conditions => {node_id_column => ActiveNode::Base.node_number(node_id)})
    end

    def find_all_by_node_id(node_ids)
      return [] unless node_ids
      node_ids = node_ids.collect {|node_id| ActiveNode::Base.node_number(node_id) }
      all(:conditions => {node_id_column => node_ids})
    end

    def active_record_class
      self
    end
  end # module ClassMethods

  module InstanceMethods
    def init_lazy_attributes(node_coll)
      lazy_attrs = LazyHash.new { node_coll.layer_data(node_id, :active_record).dup }
      instance_variable_set(:@attributes, lazy_attrs)
      instance_variable_set(:@new_record, false)
    end
  end # module InstanceMethods
end # module ActiveNode::ActiveRecord

