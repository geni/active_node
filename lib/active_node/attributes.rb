module ActiveNode
  module Attributes
    module ClassMethods

      def reset
        attr_methods.each {|attr| remove_method(attr)}
        @attr_methods = nil
        @schema       = nil
      end

      def schema
        if @schema.nil?
          @schema = read_graph('schema')
        
          node_container_class.read_graph("schema")[node_type].each do |layer, field|
            raise "struct required for contained type field #{node_type}" unless field['type'] == 'struct'
            field['fields'].each do |attr, meta|
              @schema[attr] ||= {}
              @schema[attr][layer] = meta.merge(:contained => true)
            end
          end if node_container_class

          @schema.deep_symbolize_keys!
        end
        @schema
      end

      def attr_methods
        @attr_methods ||= []
      end

      def writers(*methods)
        methods.each do |method_name|
          writer(method_name)
        end
      end

      def writer(method_name)
        method_name = method_name.to_s
        raise ArgumentError, 'writer method must end with a bang!' unless '!' == method_name.last
        name = method_name.sub(/!$/,'')
        private name rescue nil

        define_method(method_name) do |*args|
          around_method   = method(name) rescue nil
          around_method ||= lambda {|*args, &block| block.call(*args)}

          around_method.call(*args) do |*modified_args|
            Utils.ensure_arity(modified_args, 1)
            args = modified_args unless modified_args.empty? # yielding nothing means args unchanged

            arg  = args.first || {} # arg can be hash or node or node_id
            opts = arg.kind_of?(Hash) ? arg : {'id' => Utils.try(arg, :node_id) || arg}

            write_graph(name.dasherize, opts)
          end
          self
        end

      end

      def add(attrs)
        yield(attrs)
      end

      def add!(attrs)
        node = nil
        add(attrs) do |*args|
          Utils.ensure_arity(args, 1)
          node_id = next_node_id
          attrs   = args.first || {} unless args.empty?
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
              create!(attrs.merge(node_id_column => node_id))
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
        node
      end

      def attr_meta(attr, opts = {})
        layers = schema[attr.to_sym] || (raise ArgumentError, "attr #{attr} does not exist in schema")
        layer  = opts[:layer]        || (layers.keys.first if layers.size == 1)
        layer  = layer.to_s.sub('_', '-').to_sym if layer
        meta   = layers[layer]

        meta.merge(opts).merge(:layer => layer) if meta
      end

      def layer_attr(attr, opts=nil)
        @layer_attr ||= {}
        if opts
          @layer_attr[attr] = opts
        else
          @layer_attr[attr]
        end
      end

      def make_attr_method(attr, opts = {})
        meta = attr_meta(attr, opts)

        define_method(attr) do |*args|
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" unless meta or args.size == 1
          if args.empty?
            get_attr(attr, meta)
          else
            get_attr(attr, args.first)
          end
        end
        attr_methods << attr

        if meta and 'boolean' == meta[:type].to_s
          name = "#{attr}?"
          define_method(name) do
            !!send(attr)
          end
          attr_methods << name
        end
      end

      def attrs_in_schema(attrs)
        attrs = attrs.reject do |key, value|
          not schema.include?(key.to_sym)
        end

        contained_classes.each do |type, klass|
          next unless sub_attrs = attrs[type]
          attrs[type] = klass.attrs_in_schema(sub_attrs)
        end

        attrs.merge!(attrs.meta[:active_node_attrs] || {})
      end

    private

      def next_node_id
        read_graph('next-node-id')['node_id']
      end

    end # module ClassMethods

    module InstanceMethods

      def method_missing(name, *args)
        attr = name.to_s.sub(/[\?]?$/, '').to_sym
        if self.class.schema.keys.include?(attr)
          self.class.make_attr_method(attr, self.class.layer_attr(attr) || {})
          send(name, *args)
        else
          super
        end
      end

      def respond_to?(symbol, include_private = false)
        super || begin
          attr = symbol.to_s.sub(/[\?]?$/, '').to_sym
          self.class.schema.keys.include?(attr)
        end
      end

      def get_attr(attr, meta = {})
        meta  = self.class.attr_meta(attr, :layer => meta) if meta.kind_of?(Symbol)
        meta  = self.class.attr_meta(attr, meta)           if meta[:layer].nil?
        layer = meta[:layer]

        if meta[:contained]
          data = node_container.layer_data(layer)[node_type]
        else
          data = layer_data(layer)
        end
        return unless data

        attr = attr.to_s
        if klass = meta[:class]
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
          
          graph_attrs = self.class.attrs_in_schema(attrs)
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

      def reset
        @ar_instance = nil
        super rescue nil
        self
      end

    end # module InstanceMethods
  end # module Attributes
end # mmodule ActiveNode
