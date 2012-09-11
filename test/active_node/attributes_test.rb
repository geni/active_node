require File.dirname(__FILE__) + '/../test_helper'

class Birth < ActiveNode::Base
end

class Person < ActiveNode::Base
  has      :friends,      :edges    => :friends
  has      :aquaintences, :walk     => :friends_of_friends
  has      :followers,    :incoming => :followed
  contains :birth
end

require 'date'
class MyDate < Date
  def self.new(string)
    Date.parse(string)
  end
end

class AttributesTest < Test::Unit::TestCase

  def setup
    Person.reset
  end

  def next_node_id(value='person-1')
    {'node_id' => value}
  end

  def person_schema
    {
      'string' => {'a' => {'type' => 'string'}},
      'int'    => {'a' => {'type' => 'int'}},
      'bool'   => {'a' => {'type' => 'boolean'}},
      'foo'    => {'a' => {'type' => 'string'}, 'b' => {'type' => 'int'}},
      'bar'    => {'a' => {'type' => 'string'}, 'b' => {'type' => 'int'}},
      'birth'  => {
        'events' => {
          'type'   => 'struct',
          'fields' => {'date' => {'class' => 'MyDate'}},
        },
      },
    }
  end

  def birth_schema
    {
      'description' => {'b' => {'type' => 'string'}},
    }
  end

  context "An ActiveNode class" do
    context 'add!' do
      should 'call graph' do
        mock_active_node(next_node_id, person_schema) do |server|
          p = Person.add!(:string => 'string')

          assert_equal 3, server.requests.size, 'only 3 requests should have been made'

          req = server.requests.shift
          assert_equal :read,                   req[:method]
          assert_equal '/person/next-node-id',  req[:path]

          req = server.requests.shift
          assert_equal :read,                   req[:method]
          assert_equal '/person/schema',        req[:path]

          req = server.requests.shift
          assert_equal :write,                  req[:method]
          assert_equal '/person/add',           req[:path]
          assert_equal({:id => 'person-1', :string => 'string'}, req[:data])
        end
      end
    end

    context 'with active_record' do
      class ArPerson < ActiveNode::Base
        active_record('person') do
          node_id_column :node_id
        end
      end

      context 'add!' do
        should 'call create! method' do
          mock_active_node(next_node_id('42'), person_schema) do |server|
            ar_class = ArPerson.ar_class
            ar_class.stubs(:table_exists? => false, :columns => [])
            ar_class.expects(:create!).with(:node_id => 42, :string => 'string')
            ArPerson.add!(:string => 'string')
          end
        end
      end
    end

    should 'automatically create readers' do
      data1 = [{
        'id'      => 'person-1',
        'a' => {
          'string' => 'hello',
          'int'    => 42,
          'id'     => 'person-1',
          'foo'    => 'ABC',
          'bar'    => 'XYZ',
        }
      }]
      data2 = [{
        'id'      => 'person-1',
        'b' => {
          'foo'    => 123,
          'bar'    => 456,
        }
      }]

      mock_active_node(person_schema, data1, data2) do |server|
        p = Person.init('person-1')

        assert_equal false, Person.instance_methods.include?('int'),    "int should not be defined"
        assert_equal false, Person.instance_methods.include?('string'), "string should not be defined"
        assert_equal false, Person.instance_methods.include?('bool'),   "bool should not be defined"
        assert_equal false, Person.instance_methods.include?('bool?'),  "bool? should not be defined"
        assert_equal false, Person.instance_methods.include?('foo'),    "foo should not be defined"
        assert_equal false, Person.instance_methods.include?('bar'),    "bar should not be defined"

        assert_raises(ArgumentError) do
          p.foo
        end

        Person.layer_attr :bar, :layer => :a

        assert_equal 42,      p.int
        assert_equal 'hello', p.string
        assert_equal nil,     p.bool
        assert_equal false,   p.bool?
        assert_equal 'XYZ',   p.bar
        assert_equal 456,     p.bar(:b)
        assert_equal 'ABC',   p.foo(:a)
        assert_equal 123,     p.foo(:b)

        assert_equal true, Person.instance_methods.include?('int'),    "int should not be defined"
        assert_equal true, Person.instance_methods.include?('string'), "string should not be defined"
        assert_equal true, Person.instance_methods.include?('bool'),   "bool should not be defined"
        assert_equal true, Person.instance_methods.include?('bool?'),  "bool? should not be defined"
        assert_equal true, Person.instance_methods.include?('foo'),    "foo should not be defined"
        assert_equal true, Person.instance_methods.include?('bar'),    "bar should not be defined"

        assert_equal 3, server.requests.size, 'only 2 requests should have been made'

        req = server.requests.shift
        assert_equal :read,            req[:method]
        assert_equal '/person/schema', req[:path]

        req = server.requests.shift
        assert_equal :bulk_read,                 req[:method]
        assert_equal '/bulk-read',               req[:path]
        assert_equal [["/person-1/data/a", {}]], req[:data]

        req = server.requests.shift
        assert_equal :bulk_read,                 req[:method]
        assert_equal '/bulk-read',               req[:path]
        assert_equal [["/person-1/data/b", {}]], req[:data]
      end
    end
  end # context 'An ActiveNode class'

  context "An ActiveNode model" do
    context 'update!' do

      should 'update attributes' do
        data = [{
          'id'  => 'person-1',
          'a' => {
            'int' => 42,
          },
        }]

        mock_active_node(person_schema, {}, data) do |server|
          person = Person.init('person-1')
          person.update!(
            :string => 'new',
            :int    => 42,
            :bad    => 'ignore',
            :birth  => {
              :bad  => 'ignore',
              :date => '2009-05-21'
            }
          )

          assert_equal 2, server.requests.size

          req = server.requests.shift
          assert_equal :read,            req[:method]
          assert_equal '/person/schema', req[:path]

          req = server.requests.shift
          assert_equal :write,              req[:method]
          assert_equal '/person-1/update',  req[:path]

          expected = {
            'string' => 'new',
            'int'    => 42,
            'birth'  => {'date' => '2009-05-21'},
          }
          assert_equal expected,  JSON.parse(req[:body])
        end
      end

    end # context 'update!'

    context 'delete!' do

      should 'call graph' do
        mock_active_node(person_schema) do |server|
          Person.init('person-1').delete!

          assert_equal 1, server.requests.size

          req = server.requests.shift
          assert_equal :write,              req[:method]
          assert_equal '/person-1/delete',  req[:path]
        end
      end

    end # context 'delete!'


    should 'fetch layer data' do
      p = Person.init('person-42')

      response = [{
        'id'  => 'person-42',
        'foo' => {'bar' => [1,2,3]},
        'revision' => 43,
      }]

      mock_active_node(response) do |server|
        assert_equal({"bar" => [1,2,3]}, p.layer_data('foo'))

        assert_equal 1, server.requests.size

        req = server.requests.shift
        assert_equal :bulk_read,   req[:method]
        assert_equal '/bulk-read', req[:path]
        assert_equal [["/person-42/data/foo", {}]], req[:data]
      end
    end

    should 'fetch layer data at specific revisions' do
      p = Person.init('person-42')

      response1 = [{
        'id'  => 'person-42',
        'foo' => {'bar' => [1,2,3]},
        'revision' => 43,
      }]
      response2 = [{
        'id'  => 'person-42',
        'foo' => {'bar' => [5,4,3,2,1]},
        'revision' => 41,
      }]

      mock_active_node(response1, response2) do |server|
        assert_equal({"bar" => [1,2,3]}, p.layer_data('foo'))
        assert_equal({"bar" => [1,2,3]}, p.layer_data('foo', 43))

        Person.at_revision(43) do
          assert_equal({"bar" => [1,2,3]}, p.layer_data('foo'))
        end

        assert_equal 1, server.requests.size

        req = server.requests.shift
        assert_equal :bulk_read,   req[:method]
        assert_equal '/bulk-read', req[:path]
        assert_equal [["/person-42/data/foo", {}]], req[:data]

        Person.at_revision(41) do
          assert_equal({"bar" => [5,4,3,2,1]}, p.layer_data('foo'))
        end

        assert_equal({"bar" => [5,4,3,2,1]}, p.layer_data('foo', 41))

        assert_equal 1, server.requests.size

        req = server.requests.shift
        assert_equal :bulk_read,   req[:method]
        assert_equal '/bulk-read', req[:path]
        assert_equal [["/person-42/data/foo", {:revision => 41, :historical => true}]], req[:data]
      end
    end

    should 'prefetch layer data' do
      p = Person.init('person-42')

      response = [{
        'id'  => 'person-42',
        'foo' => {'bar' => [1,2,3]},
        'baz' => {'bam' => 'one'},
        'revision' => 43,
      }, {
        'id'  => 'person-42',
        'foo' => {'bar' => [5,4,3,2,1]},
        'baz' => {'bam' => 'two'},
        'revision' => 41,
      }]

      mock_active_node(response) do |server|
        p.fetch_layer_data(['foo', 'baz'], [43, 41])

        assert_equal 1, server.requests.size

        req = server.requests.shift
        assert_equal :bulk_read,   req[:method]
        assert_equal '/bulk-read', req[:path]
        assert_equal [["/person-42/data/foo,baz", {:revision => 43, :historical => true}],
                      ["/person-42/data/foo,baz", {:revision => 41, :historical => true}]], req[:data]

        assert_equal({"bar" => [1,2,3]},     p.layer_data('foo', 43))
        assert_equal({"bam" => 'one'},       p.layer_data('baz', 43))
        assert_equal({"bar" => [5,4,3,2,1]}, p.layer_data('foo', 41))
        assert_equal({"bam" => 'two'},       p.layer_data('baz', 41))

        assert_equal 0, server.requests.size
      end
    end

    context 'contains birth' do

      person_data = [{
        'id'  => 'person-1',
        'events' => {
          'birth' => {
            'date' => '2001-01-01',
          },
        },
        'revision' => 43,
      }]
      birth_data =[{
        'id'  => 'birth-1',
        'b' => {'description' => 'foo'},
        'revision' => 43,
      }]

      should 'access birth through profile' do
        Birth.reset
        mock_active_node(birth_schema, person_schema, person_data, birth_data) do |server|
          p = Person.init('person-1')
          assert_equal Birth,     p.birth.class
          assert_equal 'birth-1', p.birth.node_id
          assert_equal 1,         p.birth.date.day
          assert_equal 1,         p.birth.date.month
          assert_equal 2001,      p.birth.date.year
          assert_equal 'foo',     p.birth.description
        end
      end

      should 'init birth directly' do
        Birth.reset
        mock_active_node(birth_schema, person_schema, person_data, birth_data) do |server|
          b = Birth.init('birth-1')
          assert_equal Birth,     b.class
          assert_equal 'birth-1', b.node_id
          assert_equal 1,         b.date.day
          assert_equal 1,         b.date.month
          assert_equal 2001,      b.date.year
          assert_equal 'foo',     b.description
        end
      end
    end # context 'contains birth'

    context 'contains?' do

      should 'accept a String parameter' do
        mock_active_node(person_schema) do
          assert_equal true, Person.init('person-1').contains_type?('birth')
        end
      end

      should 'return true if type is contained' do
        mock_active_node(person_schema) do
          assert_equal true, Person.init('person-1').contains_type?(:birth)
        end
      end

      should 'return false if type is not contained' do
        mock_active_node(person_schema) do
          assert_equal false, Person.init('person-1').contains_type?(:bar)
        end
      end

    end # context 'contained_node?'

    context 'respond_to? method' do

      should 'return true for ancestor methods' do
        assert Person.init('person-42').respond_to?(:object_id)
      end

      should 'return true for schema methods' do
        mock_active_node(person_schema) do |server|
          assert Person.init('person-42').respond_to?(:string)
        end
      end

      should 'return false for invalid methods' do
        mock_active_node(person_schema) do |server|
          assert !Person.init('person-42').respond_to?(:invalid)
        end
      end

    end

  end # context 'An ActiveNode model'
end
