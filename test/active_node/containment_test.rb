require File.dirname(__FILE__) + '/../test_helper'

class Inner < ActiveNode::Base
end

class Outer < ActiveNode::Base
  contains :inner
end

class ContainmentTest < Test::Unit::TestCase

  context 'An ActiveNode class' do

    context 'contained_classes method' do

      should 'return a hash mapping type to class' do
        assert_equal({:inner => Inner}, Outer.contained_classes)
      end

    end # context 'contained_classes method'

    context 'contained_class method' do

      should 'return the class for a given type' do
        assert_equal Inner, Outer.contained_class(:inner)
      end

      should 'return nil if the type is invalid' do
        assert_equal nil, Outer.contained_class(:invalid)
      end

      should 'raise exception if type is nil' do
        assert_raise ArgumentError do
          Outer.contained_class(nil)
        end
      end

    end # context 'contained_class method'

    context 'contained_types method' do

      should 'return an array of contained types' do
        assert_equal [:inner], Outer.contained_types
      end

    end # context 'contained_types method'

    context 'contains_type? method' do

      should 'return true if the type is contained' do
        assert_equal true, Outer.contains_type?(:inner)
      end

      should 'return false if the type is invalid' do
        assert_equal false, Outer.contains_type?(:invalid)
      end

      should 'raise exception if type is nil' do
        assert_raise ArgumentError do
          Outer.contains_type?(nil)
        end
      end

    end # context 'contained_types method'

    context 'contained class' do

      context 'contained_by method' do

        should 'return containment info hash when nil parameter' do
          assert_equal({:type => 'outer', :as => :inner, :class => Outer}, Inner.contained_by)
        end

        should 'set containment info hash when non-nil parameter' do
          begin
            old_value = Inner.contained_by
            assert_equal 5, Inner.contained_by(5)
          ensure
            Inner.contained_by(old_value)
          end
        end

      end # context 'contained_by method'

      context 'node_container_class method' do

        should 'return the containing class' do
          assert_equal Outer, Inner.node_container_class
        end

        should 'return nil if not contained' do
          assert_equal nil, Outer.node_container_class
        end

      end # context 'node_container_class method'

    end # context 'contained class' 

  end # context 'An ActiveNode class'

  context 'An ActiveNode instance' do

    context 'node_container_id method' do

      should 'return the same node_number as container' do
        assert_equal 'outer-42', Outer.init(42).inner.node_container_id
      end

      should 'return nil if not contained' do
        assert_equal nil, Outer.init(42).node_container_id
      end

    end # context 'node_container_id method'

    context 'node_container method' do

      should 'return the containing instance' do
        assert_equal Outer.init(42), Outer.init(42).inner.node_container
      end

      should 'return nil if not contained' do
        assert_equal nil, Outer.init(42).node_container
      end

    end # context 'node_container method'

    context 'contained_nodes method' do

      should 'return a hash of contained_nodes' do
        assert_equal({:inner => Inner.init(42)}, Outer.init(42).contained_nodes)
      end

      should 'return empty hash if no contained_nodes' do
        assert_equal({}, Inner.init(42).contained_nodes)
      end

    end # context 'contained_nodes method'

    context 'contained_node method' do

      should 'return the contained node for a valid type' do
        assert_equal Inner.init(42), Outer.init(42).contained_node(:inner)
      end

      should 'return nil for an invalid type' do
        assert_equal nil, Outer.init(42).contained_node(:invalid)
      end

      should 'raise exception if type is nil' do
        assert_raise ArgumentError do
          Outer.init(42).contained_node(nil)
        end
      end

    end # context 'contained_node method'

    context 'contains_type? method' do

      should 'return true for contained type' do
        assert_equal true, Outer.init(42).contains_type?(:inner)
      end

      should 'return false for invalid type' do
        assert_equal false, Outer.init(42).contains_type?(:invalid)
      end

      should 'raise exception if type is nil' do
        assert_raise ArgumentError do
          Outer.init(42).contains_type?(nil)
        end
      end

    end # context 'contains_type? method'

  end # context 'An ActiveNode instance'

end # class ContainmentTest
