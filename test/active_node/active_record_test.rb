require File.dirname(__FILE__) + '/../test_helper'

class ActiveRecordTest < Test::Unit::TestCase

  context 'An ActiveNode class' do

   context 'active_record class macro' do

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

      should 'add active_record_class method' do
        assert_equal true, Person.respond_to?(:active_record_class)
      end

      should 'set node_id_column' do
        assert_equal 'foo_id', Person.active_record_class.node_id_column
      end

      should 'allow method definitions in block' do
        ar_class = Person.active_record_class
        ar_class.stubs(:table_exists? => false, :columns => [])
        assert_equal 'instance', ar_class.new.foo, 'instance method should be defined'
        assert_equal 'class', ar_class.foo, 'class method should be defined'
      end

    end
    
  end

end # class ActiveRecordTest
