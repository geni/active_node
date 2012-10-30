module ActiveNode
  module Attributes
    module ClassMethods

      def reset
        attr_methods.each {|attr| remove_method(attr)}
        @attr_methods = nil
        @schema       = nil
      end

      def attr_methods
        @attr_methods ||= []
      end

      def add(attrs)
        yield(attrs)
      end

      def add!(attrs)
        node = nil
        add(attrs) do |*args|
          Utils.ensure_arity(args, 1)
          attrs   = args.first || {} unless args.empty?
          node_id = attrs.delete(:node_id) || next_node_id
          params  = attrs.meta[:active_node_params] || {}
          path    = attrs.meta[:active_node_path]   || 'add'

          contained_classes.each do |type, klass|
            next unless sub_attrs = attrs[type]

            klass.send(:add, sub_attrs) do |*args|
              Utils.ensure_arity(args, 1)
              sub_attrs = args.first unless args.empty?
              if sub_attrs.empty?
                attrs.delete(type)
              else
                attrs[type] = sub_attrs
              end
            end
          end if attrs
          return nil if attrs.nil? or attrs.empty?

          graph_attrs = attrs_in_schema(attrs).merge!(:id => node_id)
          response    = write_graph(path, graph_attrs, params)
          node        = init(node_id)

          if ar_class
            ar_instance = ar_class.class_eval do
              create!(attrs.merge(node_id_column => ActiveNode::Base.node_number(node_id)))
            end
            node.instance_variable_set(:@ar_instance, ar_instance)
            ar_instance.instance_variable_set(:@node, node)
          end

          { # return this stuff to add() in case they need it
            :response => response,
            :node     => node,
            :attrs    => graph_attrs,
          }
        end

        node.reset
      end

      def lookup(by_attrs)
        response = read_graph('lookup', by_attrs)
        Collection.new(response['ids'])
      end

      def make_attr_method(attr, opts = {})
        schema = attr_schema(attr, opts)

        define_method(attr) do |*args|
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" unless schema or args.size == 1
          if args.empty?
            get_attr(attr, schema)
          else
            get_attr(attr, args.first)
          end
        end
        attr_methods << attr

        if schema and 'boolean' == schema[:type].to_s
          name = "#{attr}?"
          define_method(name) do
            !!send(attr)
          end
          attr_methods << name
        end
      end

    private

      def next_node_id
        read_graph('next-node-id')['node_id']
      end

    end # module ClassMethods

    module InstanceMethods

      def method_missing(name, *args)
        attr = name.to_s.sub(/[\?]?$/, '').to_sym
        if schema.keys.include?(attr)
          self.class.make_attr_method(attr, self.class.layer_attr(attr) || {})
          send(name, *args)
        else
          super
        end
      end

      def respond_to?(symbol, include_private = false)
        super || begin
          attr = symbol.to_s.sub(/[\?]?$/, '').to_sym
          schema.keys.include?(attr)
        end
      end

      def get_attr(attr, schema = {})
        schema = attr_schema(attr, :layer => schema) if schema.kind_of?(Symbol)
        schema = attr_schema(attr, schema)           if schema[:layer].nil?
        layer  = schema[:layer]

        if schema[:contained]
          data = node_container.layer_data(layer)[node_type]
        else
          data = layer_data(layer)
        end
        return unless data

        attr = attr.to_s
        if klass = schema[:class]
          return data[attr].to_sym if klass == 'Symbol'
          klass.constantize.new(data[attr])
        else
          data[attr]
        end
      end

      def update(attrs)
        yield(attrs)
      end

      def update!(attrs)
        update(attrs) do |*args|
          Utils.ensure_arity(args, 1)
          attrs  = args.first || {} unless args.empty?
          params = attrs.meta[:active_node_params] || {}
          path   = attrs.meta[:active_node_path]   || 'update'

          contained_nodes.each do |type, node|
            next unless sub_attrs = attrs[type]

            node.send(:update, sub_attrs) do |*args|
              Utils.ensure_arity(args, 1)
              sub_attrs = args.first unless args.empty?
              if sub_attrs.empty?
                attrs.delete(type)
              else
                attrs[type] = sub_attrs
              end
            end
          end if attrs
          return self if attrs.nil? or attrs.empty?

          graph_attrs = attrs_in_schema(attrs)
          response    = write_graph(path, graph_attrs, params) unless graph_attrs.empty?

          if self.class.ar_class
            ar_instance.update_attributes!(attrs)
          end

          reset
          { # return this stuff to update() in case they need it
            :response => response,
            :attrs    => graph_attrs,
          }
        end
        self
      end

      def delete
        yield
      end

      def delete!
        delete do
          response = write_graph('delete', nil)#, nil)

          if self.class.ar_class
            ar_instance.destroy
          end

          { # return this stuff to update() in case they need it
            :response => response,
          }
        end

        self
      end

      def reset
        @ar_instance = nil
        super rescue nil
        self
      end

    end # module InstanceMethods
  end # module Attributes
end # mmodule ActiveNode
