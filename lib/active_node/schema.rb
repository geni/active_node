module ActiveNode
  module Schema
    module ClassMethods

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

      def attrs_in_schema(attrs)
        filtered = filter_schema(attrs, schema, true)

        contained_classes.each do |type, klass|
          next unless sub_attrs = filtered[type]
          filtered[type] = klass.attrs_in_schema(sub_attrs)
        end

        filtered.merge!(attrs.meta[:active_node_attrs] || {})
      end

    private

      def filter_schema(value, schema, top_level=false)
        return nil unless schema

        if top_level
          return value.inject({}) do |attrs, (key, val)|
            next attrs unless schema[key.to_sym]
            next attrs unless meta = attr_meta(key)
            next attrs unless sub_schema = schema[key.to_sym][meta[:layer].to_sym]

            filtered_value = filter_schema(val, sub_schema)
            next attrs if filtered_value.blank?

            attrs.merge!(key => filtered_value)
          end
        end

        case schema[:type]
        when 'map'
          value.inject({}) do |attrs, (key, val)|
            filtered_value = filter_schema(val, schema[:values])
            next attrs if filtered_value.blank?

            attrs.merge!(key => filtered_value)
          end
        when 'struct'
          value.inject({}) do |attrs, (key, val)|
            next attrs unless sub_schema = schema[:fields][key.to_sym]

            filtered_value = filter_schema(val, sub_schema)
            next attrs if filtered_value.blank?

            attrs.merge!(key => filtered_value)
          end
        when 'list', 'set'
          value.map do |val|
            filter_schema(val, schema[:values])
          end.compact
        else
          value
        end
      end

    end # module ClassMethods

    module InstanceMethods

      def schema
        self.class.schema
      end

      def attrs_in_schema(attrs)
        self.class.attrs_in_schema(attrs)
      end

    end # module InstanceMethods
  end # module Schema
end # module ActiveNode
