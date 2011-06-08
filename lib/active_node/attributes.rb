module ActiveNode
  module Attributes
    module InstanceMethods

      def method_missing(name, *args)
        attr = name.to_s.sub(/[\?]?$/, '')
        if self.class.schema.keys.include?(attr)
          self.class.generate_methods(attr)
          send(name, *args)
        else
          super
        end
      end

      def update!(attrs)
        return unless attrs = before_update(attrs)

        write_graph('update', self.class.filtered_attrs(attrs), resource_params)

        reset
        after_update(attrs)
        return self
      end

      def before_update(attrs)
        attrs
      end

      def after_update(attrs)
      end

      def resource_params
        {}
      end

    end # module InstanceMethods

    module ClassMethods

      def reset
        @schema = nil
      end

      def schema
        @schema ||= read_graph('schema')
      end

      def add!(attrs)
        return unless attrs = before_add(attrs)

        attrs = attrs.merge(:id => next_node_id)
        write_graph('add', filtered_attrs(attrs), resource_params)
        after_add(attrs)
        return init(attrs[:id])
      end

      def before_add(attrs)
        attrs
      end

      def after_add(attrs)
      end

      def resource_params
        {}
      end

      def generate_methods(attr)
        return unless metadata = schema[attr]

        type_specific = "generate_#{metadata['type']}_methods" # eg generate_boolean_methods
        if respond_to?(type_specific)
          send(type_specific, attr)
        else
          generate_reader_method(attr)
        end
      end

      def generate_reader_method(attr)
        define_method(attr) do 
          layer_data(self.class.schema[attr]['layer'])[attr]
        end
      end

      def generate_boolean_methods(attr)
        define_method("#{attr}?") do
          !! layer_data(self.class.schema[attr]['layer'])[attr]
        end
      end

      def filtered_attrs(attrs)
        attrs.reject {|key, value| not schema.include?(key.to_s)}
      end

    private

      def next_node_id
        read_graph('next-node-id')['node_id']
      end

    end # module ClassMethods

  end # module Attributes
end # mmodule ActiveNode
