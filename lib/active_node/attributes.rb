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

          node_container_class.read_graph("schema/#{node_type}").each do |attr, layers|
            layers.each do |layer, meta|
              @schema[attr] ||= {}
              @schema[attr][layer] = meta.merge(:contained => true)
            end if layers.kind_of?(Hash)
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
            args = modified_args unless modified_args.empty?
            opts = Utils.extract_options(args)
            opts = {'id' => Utils.try(opts, :node_id) || opts} unless opts.kind_of?(Hash)

            write_graph(name.dasherize, opts)
          end
          self
        end

      end

      def add!(attrs)
        attrs   = modify_add_attrs(attrs)
        params  = attrs.meta[:active_node_params] || {}
        path    = attrs.meta[:active_node_path] || 'add'
        node_id = next_node_id

        contained_classes.each do |type, klass|
          next unless sub_attrs = attrs[type]
          if sub_attrs = klass.modify_add_attrs(sub_attrs)
            attrs[type] = sub_attrs
          else
            attrs.delete(type)
          end
        end if attrs
        return self if attrs.nil? or attrs.empty?

        graph_attrs = attrs_in_schema(attrs).merge!(attrs.meta[:active_node_attrs] || {}).merge!(:id => node_id)
        response    = write_graph(path, graph_attrs, params)
        node        = init(node_id)

        if ar_class
          ar_instance = ar_class.class_eval do
            create!(attrs.merge(node_id_column => node_id))
          end
          node.instance_variable_set(:@ar_instance, ar_instance)
          ar_instance.instance_variable_set(:@node, node)
        end

        node.send(:after_add, response.vary_meta(:merge, :attrs => graph_attrs))

        node
      end

      def layer_attrs(attr_to_layer)
        attr_to_layer.each do |attr, opts|
          layer_attr attr, opts
        end
      end

      def attr_meta(attr, opts = {})
        layers = schema[attr]  || (raise ArgumentError, "attr #{attr} does not exist in schema")
        layer  = opts[:layer]  || (layers.keys.first if layers.size == 1)
        layer  = layer.to_s.sub('_', '-').to_sym if layer
        meta   = layers[layer]

        meta.merge(opts).merge(:layer => layer) if meta
      end

      def layer_attr(attr, opts = {})
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
          key = key.to_sym
          not schema.include?(key)
        end

        contained_classes.each do |type, klass|
          next unless sub_attrs = attrs[type]
          attrs[type] = klass.attrs_in_schema(sub_attrs)
        end

        attrs
      end

      def modify_attrs(attrs)
        # By default this is called by modify_add_attrs and modify_update_attrs.
        attrs
      end

      def modify_add_attrs(attrs)
        # Called before add! is executed to modify attrs being passed in.
        modify_attrs(attrs)
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
          self.class.layer_attr(attr)
          send(name, *args)
        else
          super
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

      def update!(attrs)
        attrs  = modify_update_attrs(attrs)
        params = attrs.meta[:active_node_params] || {}

        contained_nodes.each do |type, node|
          next unless sub_attrs = attrs[type]
          sub_attrs = node.modify_update_attrs(sub_attrs)
          if sub_attrs.blank? || sub_attrs.empty?
            attrs.delete(type)
          else
            attrs[type] = sub_attrs
          end
        end if attrs
        return self if attrs.nil? or attrs.empty?

        schema_attrs = self.class.attrs_in_schema(attrs)
        response = write_graph('update', schema_attrs, params) unless schema_attrs.empty?

        if self.class.ar_class
          ar_instance.update_attributes!(attrs)
        end

        reset
        after_update(response) if response
        self
      end

      def reset
        ar_instance.try(:reload) if self.class.ar_class
        super rescue nil
      end

      def modify_update_attrs(attrs)
        # Called before update! is executed to modify attrs being passed in.
        self.class.modify_attrs(attrs)
      end

      def after_update(response)
        # Called after update! is complete with the server response.
      end

      def after_add(response)
        # Called after add! is complete with the server response.
      end

    end # module InstanceMethods
  end # module Attributes
end # mmodule ActiveNode
