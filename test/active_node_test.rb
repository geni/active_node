require File.dirname(__FILE__) + '/test_helper'

class Person < ActiveNode::Base
  has :friends,      :edges    => :friends
  has :aquaintences, :walk     => :friends_of_friends
  has :followers,    :incoming => :followed
end

class Other < ActiveNode::Base
end

class ActiveNodeTest < Test::Unit::TestCase
  include ActiveNode::TestHelper

  context "An ActiveNode class" do

    should "send attributes as JSON body on write" do
      mock_active_node({ :name => 'Harley'}) do |server|
        Person.write_graph('add', 'name' => 'Harley')
        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :write,                       req[:method]
        assert_equal  '/person/add',                req[:path]
        assert_equal( {'name' => 'Harley'}.to_json, req[:body])
      end
    end

    should 'load properly from MethodCache' do
      assert_equal Person.init('person-42'), ActiveNode::Base._load(Marshal.dump('person-42'))
    end

    context 'init method' do
      should 'raise ArgumentError if node_class does not match' do
        ex = assert_raise ArgumentError do
          Person.init('string-1')
        end
        assert_match 'cannot init', ex.message
      end
    end

    context 'node_type method' do

      should 'set node type' do
        foo = Class.new(ActiveNode::Base)
        foo.node_type('bar')
        assert_equal 'bar', foo.node_type
      end

      should 'return the default node_type' do
        Object.const_set('Foo',  Class.new(ActiveNode::Base))
        assert_equal 'foo', Foo.node_type
      end

    end # context 'node_type method'

    context 'headers method' do

      should 'return empty hash by default' do
        assert_equal({}, Person.headers)
      end

    end # context 'headers method'

    context 'write_graph method' do

      should 'should set graph_response metadata' do
        response = {:foo => 'bar'}
        mock_active_node(response) do |server|
          data = {:id => 42}
          Person.write_graph('/person/foo', data)
          assert_equal response, data.meta[:graph_response]
        end
      end

    end # context 'write_graph method'

  end # context 'An ActiveNode class'

  context 'An ActiveNode instance' do

    should "set @node_id in init" do
      assert_equal 'person-43', Person.init('person-43').instance_variable_get(:@node_id)
      assert_equal 'person-43', Person.init(43).instance_variable_get(:@node_id)
    end

    should "send attributes as JSON body on write" do
      mock_active_node do |server|
        Person.init('person-1').write_graph('update', { :name => 'Charlie' })

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :write,                        req[:method]
        assert_equal  '/person-1/update',            req[:path]
        assert_equal( {'name' => 'Charlie'}.to_json, req[:body])
      end
    end

    should "read all attributes when called with no resource" do
      mock_active_node do |server|
        Person.init('person-1').read_graph('')

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :read,        req[:method]
        assert_equal  '/person-1/', req[:path]
      end
    end

    should "read specified attributes when called with resource" do
      mock_active_node do |server|
        #server = Person.mock_server
        Person.init('person-1').read_graph('profile')

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :read,               req[:method]
        assert_equal  '/person-1/profile', req[:path]
      end
    end

    should 'pass extra params on query string' do
      mock_active_node do |server|
        #server = Person.mock_server
        Person.init('person-1').write_graph('update', { :name => 'Bob' }, { 'test' => 'testing' })

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal '/person-1/update', req[:path]
        assert_equal 'testing',          req[:params]['test']
      end
    end

    should 'use default path on read' do
      mock_active_node do |server|
        Person.init('person-7').read_graph('revision' => 876)

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :read,               req[:method]
        assert_equal  '/person-7/node',    req[:path]
        assert_equal( {"revision" => 876}, req[:params] )
      end
    end

    should 'bulk read' do
      mock_active_node([]) do |server|
        ActiveNode.bulk_read do
          Person.init('person-5').read_graph
          Person.init('person-7').read_graph
        end

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal :bulk_read,   req[:method]
        assert_equal '/bulk-read', req[:path]
        assert_equal [['/person-5/node', {}],
                      ['/person-7/node', {}]].to_json, req[:body]
      end
    end

    should 'dump properly to MethodCache' do
      assert_equal Marshal.dump('person-42'), Person.init('person-42')._dump(nil)
    end

    should 'be equal when class and node_id are the same' do
      assert Person.init('person-42') == Person.init('person-42')
      assert Person.init('person-42').eql?(Person.init('person-42')), 'hash-equality failed'
    end

    should 'be unequal when node_id is different' do
      assert !(Person.init('person-42') == Person.init('person-43'))
      assert !Person.init('person-42').eql?(Person.init('person-43')), 'hash-inequality failed'
    end

  end # context 'An ActiveNode instance'

end
