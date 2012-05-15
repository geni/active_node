module ActiveNode
  module Schema
    module ClassMethods

      def node_container_class
        nil # overridden in active_node/containment
      end

      def schema
        if @schema.nil?
          @schema = read_graph('schema')

          node_container_class.read_graph("schema")[node_type].each do |layer, field|
            raise "struct required for contained type field #{node_type}" unless field['type'] == 'struct'
            field['fields'].each do |attr, schema|
              @schema[attr] ||= {}
              @schema[attr][layer] = schema.merge(:contained => true)
            end
          end if node_container_class

          @schema.deep_symbolize_keys!
        end
        @schema
      end

      def attrs_in_schema(attrs)
        filtered = filter_schema(attrs, schema, true)
        filtered.merge!(attrs.meta[:active_node_attrs] || {})
      end

      def attr_schema(attr, opts = layer_attr(attr))
        layers = schema[attr.to_sym] || (raise ArgumentError, "attr #{attr} does not exist in schema")
        layer  = opts[:layer]        || (layers.keys.first if layers.size == 1)
        layer  = layer.to_s.sub('_', '-').to_sym if layer
        schema = layers[layer]

        schema.merge(opts).merge(:layer => layer) if schema
      end

      def layer_attr(attr, opts=nil)
        @layer_attr ||= {}
        if opts
          @layer_attr[attr] = opts
        else
          @layer_attr[attr] || {}
        end
      end

    private

      def filter_schema(value, schema, top_level=false)
        return nil unless schema

        if top_level
          return value.inject({}) do |attrs, (key, val)|
            next attrs unless schema[key.to_sym]
            next attrs unless attr_schema = attr_schema(key)
            next attrs unless sub_schema  = schema[key.to_sym][attr_schema[:layer].to_sym]

            attrs.merge!(key => filter_schema(val, sub_schema))
          end
        end

        case schema[:type]
        when 'map'
          value.inject({}) do |attrs, (key, val)|
            attrs.merge!(key => filter_schema(val, schema[:values]))
          end
        when 'struct'
          value.inject({}) do |attrs, (key, val)|
            next attrs unless sub_schema = schema[:fields][key.to_sym]
            attrs.merge!(key => filter_schema(val, sub_schema))
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

      def attrs_in_schema(*args)
        self.class.attrs_in_schema(*args)
      end

      def attr_schema(*args)
        self.class.attr_schema(*args)
      end

    end # module InstanceMethods
  end # module Schema
end # module ActiveNode
