require File.dirname(__FILE__) + '/../test_helper'

class Person < ActiveNode::Base
  has :friends,      :edges    => :friends
  has :aquaintences, :walk     => :friends_of_friends
  has :followers,    :incoming => :followed
end

class Person < ActiveNode::Base
  active_record('person') do
    node_id_column :node_id
  end
end

class AttributesTest < Test::Unit::TestCase

  def setup
    Person.reset
  end

  def next_node_id(value='person-1')
    {'node_id' => value}
  end

  def schema
    {
      'id'      => {'layer' => 'layer-1', 'type' => 'string'},
      'string'  => {'layer' => 'layer-1', 'type' => 'string'},
      'int'     => {'layer' => 'layer-1', 'type' => 'int'},
      'bool'    => {'layer' => 'layer-1', 'type' => 'boolean'},
    }
  end

  context "An ActiveNode class" do

    context 'add!' do

      should 'call graph' do
        mock_active_node(next_node_id, schema) do |server|
          p = Person.add!(:string => 'string')

          assert_equal 3, server.requests.size, 'only 2 requests should have been made'

          req = server.requests.shift
          assert_equal :get,                    req[:method]
          assert_equal '/person/next-node-id',  req[:path]

          req = server.requests.shift
          assert_equal :get,                    req[:method]
          assert_equal '/person/schema',        req[:path]

          req = server.requests.shift
          assert_equal :post,                   req[:method]
          assert_equal '/person/add',           req[:path]
          assert_equal({:id => 'person-1', :string => 'string'},  req[:data])
        end
      end

      should 'call modify_add_attrs with attrs' do
        mock_active_node(next_node_id, schema) do
          Person.expects(:modify_add_attrs).with(:string => 'one').returns(:string => 'one')
          Person.add!(:string => 'one')
        end
      end

      should 'call after_add with attrs' do
        mock_active_node(next_node_id, schema, {:response => 1}) do
          Person.any_instance.expects(:after_add).with(:response => 1)
          Person.add!(:string => 'one')
        end
      end

    end

    context 'with active_record' do

      context 'add!' do
        should 'call create! method' do
          mock_active_node(next_node_id('42'), schema) do |server|
            ar_class = Person.active_record_class
            ar_class.stubs(:table_exists? => false, :columns => [])
            ar_class.expects(:create!).with(:node_id => '42', :string => 'string')
            Person.add!(:string => 'string')
          end
        end
      end

    end


    should 'automatically create readers' do

      data = [{
        'id'      => 'person-1',
        'layer-1' => {
          'string' => 'string',
          'int'    => 42,
          'boolean'=> true,
        },
      }]

      mock_active_node(schema, data) do |server|
        p = Person.init('person-1')

        ['string', 'int'].each do |attr|
          assert_equal false, Person.instance_methods.include?(attr), "#{attr} should not be defined"
          p.send(attr)
          assert_equal true, Person.instance_methods.include?(attr), "#{attr} should be defined"
        end

        assert_equal false, Person.instance_methods.include?('bool?'), "bool? should not be defined"
        p.bool?
        assert_equal true, Person.instance_methods.include?('bool?'), "bool? should be defined"

        assert_equal 2, server.requests.size, 'only 2 requests should have been made'

        req = server.requests.shift
        assert_equal :get,             req[:method]
        assert_equal '/person/schema', req[:path]

        req = server.requests.shift
        assert_equal :post,         req[:method]
        assert_equal '/bulk-read',  req[:path]
      end
    end

  end

  context "An ActiveNode model" do

    context 'update!' do

      should 'update attributes' do

        schema = {
          'string'  => {'layer' => 'layer-1', 'type' => 'string'},
          'int'     => {'layer' => 'layer-2', 'type' => 'int'},
        }

        data = [{
          'id'      => 'person-1',
          'layer-2' => {
            'int'    => 42,
          },
        }]

        mock_active_node(schema, {}, data) do |server|
          person = Person.init('person-1')
          person.update!({:string => 'new', :int => 42, :bad => 'ignore'})

          assert_equal 2, server.requests.size

          req = server.requests.shift
          assert_equal  :get,             req[:method]
          assert_equal  '/person/schema', req[:path]

          req = server.requests.shift
          assert_equal :post,               req[:method]
          assert_equal '/person-1/update',  req[:path]
          assert_equal({'string' => 'new', 'int' => 42},  JSON.parse(req[:body]))
        end
      end

      should 'call modify_update_attrs' do
        mock_active_node(schema) do
          Person.any_instance.expects(:modify_update_attrs).with(:string => 'one').returns(:string => 'one')
          Person.init('person-1').update!(:string => 'one')
        end
      end

      should 'call after_update with attrs' do
        mock_active_node(schema, {:response => 1}) do
          Person.any_instance.expects(:after_update).with(:response => 1)
          Person.init('person-1').update!(:string => 'one')
        end
      end

    end
  end
end
