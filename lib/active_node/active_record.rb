module ActiveNode::ActiveRecord

  def active_record(table_name, opts={}, &block)
    @ar_class = Class.new(ar_parent_class)
    const_set("ActiveRecord", @ar_class) unless const_defined?("ActiveRecord")
    @ar_class.set_table_name(table_name)
    @ar_class.set_inheritance_column(:_disabled)
    @ar_class.send(:extend,  ClassMethods)
    @ar_class.send(:include, InstanceMethods)

    active_record_compatibility if opts[:compatibility]

    define_method :ar_instance do
      if @ar_instance.nil?
        @ar_instance = find_ar_instance || new_ar_instance
        @ar_instance.instance_variable_set(:@node, self)
      end
      @ar_instance
    end

    define_method :find_ar_instance do
      self.class.ar_class.find_by_node_id(node_number)
    end
    private :find_ar_instance

    define_method :new_ar_instance do
      self.class.ar_class.new(:node_id => node_number)
    end
    private :new_ar_instance

    if block_given?
      @ar_class.class_eval(&block)
    end
  end

  def ar_parent_class
    if ActiveNode::Base == superclass
      ActiveRecord::Base
    elsif defined?(superclass::ActiveRecord)
      superclass::ActiveRecord
    else
      ActiveRecord::Base
    end
  end

  # TODO: may be able to get rid of parameter now that we have superclass recursion
  def ar_class(type = nil)
    return ActiveNode::Base.node_class(type).ar_class if type
    @ar_class ||= superclass.try(:ar_class) rescue nil
  end

  module ClassMethods
    def node_id_column(column = nil)
      if column
        @node_id_column = column
      else
        @node_id_column ||= :node_id
      end
    end

    def ar_class
      self
    end

  end # module ClassMethods

  module InstanceMethods

    def node
      @node
    end

    def init_lazy_attributes
      lazy_attrs = LazyHash.new { node_collection.layer_data(node_id, :active_record).dup }
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

  def clear
    @hash = nil
  end
end
