require File.dirname(__FILE__) + '/../test_helper'

class ActiveRecordTest < Test::Unit::TestCase

  context 'An ActiveNode class' do
    context 'active_record class macro' do
      should 'allows method definition in block' do
        class Person < ActiveNode::Base
          active_record('people') do
            node_id_column 'foo_id'

            def foo
              'instance'
            end

            def self.foo
              'class'
            end
          end
        end

        ar_class = Person.instance_variable_get(:@ar_class)
        ar_class.stubs(:table_exists? => false, :columns => [])
        assert_equal 'instance', ar_class.new.foo, 'instance method should be defined'
        assert_equal 'class', ar_class.foo, 'class method should be defined'
        assert_equal 'foo_id', ar_class.node_id_column
      end
    end
  end

end # class ActiveRecordTest
