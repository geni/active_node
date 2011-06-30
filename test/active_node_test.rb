require File.dirname(__FILE__) + '/test_helper'

class Person < ActiveNode::Base
  has :friends,      :edges    => :friends
  has :aquaintences, :walk     => :friends_of_friends
  has :followers,    :incoming => :followed
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

  end

  context "An ActiveNode model" do

    should "set @node_id in init" do
      t = Person.init('model-43')
      assert_equal 'model-43', t.instance_variable_get(:@node_id)
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
  end

end
