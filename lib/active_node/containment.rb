module ActiveNode
  module Containment
    module ClassMethods

      def contains(*types)
        types.each do |type|
          klass = type.to_s.classify.constantize
          contained_classes[type] = klass
          klass.contained_by(:type => node_type, :class => self, :as => type)

          define_method(type) do
            contained_node(type)
          end
        end
      end

      def contained_classes
        @contained_classes ||= {}
      end

      def contained_class(type)
        raise ArgumentError, 'Type cannot be nil' unless type
        contained_classes[type.to_sym]
      end

      def contained_types
        contained_classes.keys
      end

      def contains_type?(type)
        raise ArgumentError, 'Type cannot be nil' unless type
        contained_classes.has_key?(type.to_sym)
      end

      def contained_by(opts = nil)
        return @contained_by unless opts
        @contained_by = opts
      end

      def node_container_class
        return unless contained_by
        @node_container_class ||= contained_by[:class]
      end

    end # module ClassMethods

    module InstanceMethods

      def node_container_id
        return unless contained_by = self.class.contained_by
        @node_container_id ||= "#{contained_by[:type]}-#{node_number}"
      end

      def node_container
        return unless self.class.contained_by
        @node_container ||= self.class.node_container_class.init(node_container_id)
      end

      def contained_as
        self.class.contained_by[:as]
      end

      def contained_nodes
        @contained_nodes ||= {}
        self.class.contained_classes.each do |type, klass|
          @contained_nodes[type] ||= contained_node(type)
        end
        @contained_nodes
      end

      def update!(attrs)
        if node_container
          node_container.update!({contained_as => attrs})
        else
          super
        end
      end

      def contained_node(type)
        raise ArgumentError, 'Type cannot be nil' unless type
        type = type.to_sym
        return unless klass = self.class.contained_class(type)
        @contained_nodes ||= {}
        @contained_nodes[type] ||= klass.init("#{type}-#{node_number}", :container => self)
      end

      def contains_type?(type)
        raise ArgumentError, 'Type cannot be nil' unless type
        self.class.contains_type?(type.to_sym)
      end

    end # module InstanceMethods
  end
end
