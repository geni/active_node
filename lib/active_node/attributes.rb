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

        response = write_graph('update', self.class.attrs_in_schema(attrs), resource_params)
        if self.class.respond_to?(:active_record_class)
          record = self.class.active_record_class.find_by_node_id(node_id)
          record.update_attributes!(attrs)
        end

        reset
        after_update(response)
        return self
      end

      def before_update(attrs)
        attrs
      end

      def after_update(response)
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

        node_id  = next_node_id
        response = write_graph('add', attrs_in_schema(attrs.merge(:id => node_id)), resource_params)
        if respond_to?(:active_record_class)
          active_record_class.create!(attrs.merge(node_id_column => node_id))
        end

        after_add(response)
        return init(node_id)
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

      def attrs_in_schema(attrs)
        attrs.reject {|key, value| not schema.include?(key.to_s)}
      end

    private

      def next_node_id
        read_graph('next-node-id')['node_id']
      end

    end # module ClassMethods

  end # module Attributes
end # mmodule ActiveNode
