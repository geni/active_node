module ActiveNode
  module Attributes
    module ClassMethods

      def reset
        @schema = nil
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
        end
        @schema
      end

      def add!(attrs)
        return self unless attrs = modify_add_attrs(attrs)
        params  = attrs.meta[:active_node_params] || {}
        node_id = next_node_id

        contained_types.each do |type, klass|
          next unless sub_attrs = attrs[type]
          attrs[type] = klass.modify_add_attrs(sub_attrs)
        end

        if ar_class
          ar_instance = ar_class.class_eval do
            create!(attrs.merge(node_id_column => node_id))
          end
        end

        response = write_graph('add', attrs_in_schema(attrs.merge(:id => node_id)), params)
        node     = init(node_id)
        node.after_add(response)

        node.instance_variable_set(:@ar_instance, ar_instance)
        ar_instance.instance_variable_set(:@node, node)

        node
      end

      def layer_attrs(attr_to_layer)
        attr_to_layer.each do |attr, layer|
          layer_attr attr, layer
        end
      end

      def layer_attr(attr, default_layer = nil, opts = {})
        attr = attr.to_s

        if default_layer
          type = opts[:type]
        else
          raise "cannot create reader for attr #{attr} not in schema" unless attr_schema = schema[attr]
          if attr_schema.size == 1
            default_layer = attr_schema.keys.first
            type          = attr_schema.values.first['type']
          end
        end
        default_layer = default_layer.to_s  if default_layer

        define_method(attr) do |*args|
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" unless default_layer or args.size == 1
          layer = (args.first || default_layer).to_s
          raise "attr #{attr} does not exist on layer #{layer}" unless schema = self.class.schema[attr][layer]

          data = if schema[:contained]
            node_container.layer_data(layer)[node_type.to_s]
          else
            layer_data(layer)
          end

          return unless data

          if klass = schema['class']
            klass.constantize.new(data[attr])
          else
            data[attr]
          end
        end

        if default_layer and 'boolean' == type.to_s
          define_method("#{attr}?") do
            !!layer_data(default_layer)[attr]
          end
        end
      end

      def attrs_in_schema(attrs)
        attrs = attrs.reject do |key, value|
          key = key.to_s
          key != "id" and not schema.include?(key)
        end

        contained_types.each do |type, klass|
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

      def contains(*types)
        types.each do |type|
          klass = type.to_s.classify.constantize
          contained_types[type] = klass
          klass.contained_by(:type => node_type, :class => self)

          define_method(type) do
            @contained_nodes ||= {}
            @contained_nodes[type] ||= klass.init("#{type}-#{node_number}", :container => self)
          end
        end
      end

      def contained_types
        @contained_types ||= {}
      end

      attr_reader :contained_by_class
      def contained_by(opts = nil)
        return @contained_by unless opts
        @contained_by = opts
      end

      def node_container_class
        return unless contained_by
        @node_container_class ||= contained_by[:class]
      end

    private

      def next_node_id
        read_graph('next-node-id')['node_id']
      end

    end # module ClassMethods

    module InstanceMethods

      def method_missing(name, *args)
        attr = name.to_s.sub(/[\?]?$/, '')
        if self.class.schema.keys.include?(attr)
          self.class.layer_attr(attr)
          send(name, *args)
        else
          super
        end
      end

      def node_container_id
        return unless contained_by = self.class.contained_by
        @node_container_id ||= "#{contained_by[:type]}-#{node_number}"
      end

      def node_container
        return unless self.class.contained_by
        @node_container ||= self.class.node_container_class.init(node_container_id)
      end

      def contained_nodes
        @contained_nodes ||= {}
        self.class.contained_types.each do |type, klass|
          @contained_nodes[type] ||= send(type)
        end
        @contained_nodes
      end

      def update!(attrs)
        return self unless attrs = modify_update_attrs(attrs)
        params = attrs.meta[:active_node_params] || {}

        contained_nodes.each do |type, node|
          next unless sub_attrs = attrs[type]
          attrs[type] = node.modify_update_attrs(sub_attrs)
        end
        response = write_graph('update', self.class.attrs_in_schema(attrs), params)

        if self.class.ar_class
          ar_instance.update_attributes!(attrs)
        end

        reset
        after_update(response)
        self
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
