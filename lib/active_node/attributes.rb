module ActiveNode
  module Attributes
    module InstanceMethods

      def method_missing(name, *args)
        name = name.to_s
        if self.class.schema.keys.include?(name)
          self.class.generate_methods(name)
          send(name, *args)
        else
          super
        end
      end

    end # module InstanceMethods

    module ClassMethods

      def schema
        @schema ||= read_graph('schema')
      end

      def generate_methods(attribute)
        generate_reader_method(attribute)
      end

      def generate_reader_method(attribute)
        return unless schema[attribute]

        method_definition = <<-EOM
          def #{attribute}
            layer_data('#{schema[attribute]['layer']}')['#{attribute}']
          end
        EOM

        class_eval(method_definition, __FILE__)
      end

    end # module ClassMethods

  end # module Attributes
end # mmodule ActiveNode
