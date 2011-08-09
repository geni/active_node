module ActiveNode
  module Containment
    module ClassMethods

      def contains(*types)
        types.each do |type|
          klass = type.to_s.classify.constantize
          contained_classes[type] = klass
          klass.contained_by(:type => node_type, :class => self)

          define_method(type) do
            contained_node(type)
          end
        end
      end

      def contained_classes
        @contained_classes ||= {}
      end

      def contained_class(type)
        contained_classes[type]
      end

      def contains_type?(type)
        contained_classes.has_key?(type)
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

      def contained_nodes
        @contained_nodes ||= {}
        self.class.contained_classes.each do |type, klass|
          @contained_nodes[type] ||= contained_node(type)
        end
        @contained_nodes
      end

      def contained_node(type)
        return unless klass = self.class.contained_class(type)
        @contained_nodes ||= {}
        @contained_nodes[type] ||= klass.init("#{type}-#{node_number}", :container => self)
      end

      def contains_type?(type)
        self.class.contains_type?(type)
      end

    end # module InstanceMethods
  end
end
