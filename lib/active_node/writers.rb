module ActiveNode
  module Writers
    module ClassMethods

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
          around_method   = method(name).untaint rescue nil             # untaint to prevent SecurityError
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

    end # module ClassMethods
  end # module Writers
end # module ActiveNode
