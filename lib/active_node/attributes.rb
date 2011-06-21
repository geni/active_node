module ActiveNode
  module Attributes
    module ClassMethods

      def reset
        @schema = nil
      end

      def schema
        @schema ||= read_graph('schema')
      end

      def add!(attrs)
        attrs    = modify_add_attrs(attrs)
        node_id  = next_node_id
        response = write_graph('add', attrs_in_schema(attrs.merge(:id => node_id)))
        if active_record_class
          active_record_class.class_eval do
            create!(attrs.merge(node_id_column => node_id))
          end
        end

        node = init(node_id)
        node.after_add(response)
        node
      end

      attr_reader :revision

      def at_revision(revision)
        @revision, old_revision = revision, @revision
        yield
      ensure
        @revision = old_revision
      end

      def generate_method(attr)
        return unless metadata = schema[attr]

        type_specific = "generate_#{metadata['type']}_method" # eg generate_boolean_methods
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

      def generate_boolean_method(attr)
        define_method("#{attr}?") do
          !! layer_data(self.class.schema[attr]['layer'])[attr]
        end
      end

      def attrs_in_schema(attrs)
        attrs.reject {|key, value| not schema.include?(key.to_s)}
      end

      def modify_add_attrs(attrs)
        # Called before add! is executed to modify attrs being passed in.
        attrs
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
          self.class.generate_method(attr)
          send(name, *args)
        else
          super
        end
      end

      def update!(attrs)
        attrs    = modify_update_attrs(attrs)
        response = write_graph('update', self.class.attrs_in_schema(attrs))
        if self.class.active_record_class
          record = self.class.active_record_class.find_by_node_id(node_id)
          record.update_attributes!(attrs)
        end

        reset
        after_update(response)
        self
      end

      def layer_data(layer, revision = self.class.revision)
        @node_coll.layer_data(node_id, layer, revision)
      end

      def revisions(layers)
        return revisions([layers])[layers] unless layers.kind_of?(Array)
        revisions = {}
        layers.each do |layer|
          revisions[layer] = @node_coll.layer_revisions(node_id, layer)
        end
        revisions
      end

      def fetch_layer_data(layers, revisions)
        @node_coll.fetch_layer_data(node_type, layers, revisions)
      end

      def fetch_layer_revisions(layers)
        @node_coll.fetch_layer_revisions(node_type, layers)
      end

      def modify_update_attrs(attrs)
        # Called before update! is executed to modify attrs being passed in.
        attrs
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
