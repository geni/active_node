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

      class Vip < Person
        active_record('people') do
          def bar
            'instance'
          end
        end
      end

      should 'add ar_class method' do
        assert_equal true, Person.respond_to?(:ar_class)
      end

      should 'set node_id_column' do
        assert_equal 'foo_id', Person.ar_class.node_id_column
      end

      should 'allow method definitions in block' do
        ar_class = Person.ar_class
        ar_class.stubs(:table_exists? => false, :columns => [])
        assert_equal 'instance', ar_class.new.foo, 'instance method should be defined'
        assert_equal 'class',    ar_class.foo,     'class method should be defined'

        assert_equal ActiveRecordTest::Person::ActiveRecord,   ar_class
        assert_equal 'ActiveRecordTest::Person::ActiveRecord', ar_class.name
      end

      should 'have an ar_instance' do
        p = Person.init(1)
        columns = [
          ActiveRecord::ConnectionAdapters::Column.new('node_id', nil, 'int')
        ]
        Person.ar_class.stubs(:table_exists? => false, :columns => columns, :find => nil)
        assert_equal 1, p.ar_instance.node_id
        assert_equal p, p.ar_instance.node
      end

      context 'ar_class' do

        should 'should extend correct class' do
          Person.ar_class.stubs(:table_exists? => false, :columns => [])
          Vip.ar_class.stubs(:table_exists? => false, :columns => [])
          assert_equal ActiveRecord::Base, Person.ar_class.superclass
          assert_equal Person::ActiveRecord, Vip.ar_class.superclass
          assert_equal 'instance', Vip.ar_class.new.foo, 'instance method should be inherited'
          assert_equal 'instance', Vip.ar_class.new.bar, 'instance method should be define'
        end
      end # context ar_class

    end # context 'active_record class macro'
  end # context 'An ActiveNode class'

  context 'An ActiveRecord::Base class' do

    context 'with active_node mixed in' do

      class ArPerson < ActiveRecord::Base
        active_node
      end

    end

  end

end # class ActiveRecordTest
