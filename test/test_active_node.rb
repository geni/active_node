require File.dirname(__FILE__) + '/test_helper'

class TestModel < ActiveNode::Base; end

class ActiveNodeTest < Test::Unit::TestCase
  include ActiveNode::TestHelper

  context "mocked graph server" do
    should "yield" do
      assert_raise(RuntimeError) do
        mock_active_node do |server|
          raise 'ok!'
        end
      end
    end
  end

  context "An ActiveNode class" do
    should "send attributes as JSON body on write" do
      mock_active_node({ :name => 'Harley'}) do |server|
        TestModel.write_graph('add', 'name' => 'Harley')
        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :put,                         req[:method]
        assert_equal  '/test_model/add',            req[:path]
        assert_equal( {'name' => 'Harley'}.to_json, req[:body])
      end
    end
  end

  context "An ActiveNode model" do
    should "set @node_id in init" do
      t = TestModel.init('model-43')
      assert_equal 'model-43', t.instance_variable_get(:@node_id)
    end

    should "set cached layer_data in init" do
      t = TestModel.init( 'test_model' => {:name => 'Charlie', 'occupation' => 'chocolate maker'} )

      assert_equal [:test_model],     t.layer_data.keys
      assert_equal 'Charlie',         t.layer_data[:test_model][:name]
      assert_equal 'chocolate maker', t.layer_data[:test_model]['occupation']
    end

    should "send attributes as JSON body on write" do
      mock_active_node do |server|
        TestModel.init('test_model-1').write_graph('update', { :name => 'Charlie' })

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :put,                          req[:method]
        assert_equal  '/test_model-1/update',        req[:path]
        assert_equal( {'name' => 'Charlie'}.to_json, req[:body])
      end
    end

    should "read all attributes when called with no resource" do
      mock_active_node do |server|
        TestModel.init('test_model-1').read_graph('')

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :post,            req[:method]
        assert_equal  '/test_model-1/', req[:path]
      end
    end

    should "read specified attributes when called with resource" do
      mock_active_node do |server|
        #server = TestModel.mock_server
        TestModel.init('test_model-1').read_graph('profile')

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :post,                   req[:method]
        assert_equal  '/test_model-1/profile', req[:path]
      end
    end

    should 'pass extra params on query string' do
      mock_active_node do |server|
        #server = TestModel.mock_server
        TestModel.init('test_model-1').write_graph('update', { :name => 'Bob' }, { 'test' => 'testing' })

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal '/test_model-1/update', req[:path]
        assert_equal 'testing',              req[:params]['test']
      end
    end

    should 'override latest_revision with params' do
      mock_active_node do |server|
        ActiveNode.stubs(:latest_revision).returns(654)
        TestModel.init('test_model-1').read_graph('', 'revision' => 876)

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :post,                      req[:method]
        assert_equal  '/test_model-1/',           req[:path]
        assert_equal( {:revision => 876}.to_json, req[:body] )
      end
    end

    should 'use default path on read' do
      mock_active_node do |server|
        TestModel.init('test_model-7').read_graph('revision' => 876)

        assert_equal 1, server.requests.size
        req = server.requests.shift

        assert_equal  :post,                      req[:method]
        assert_equal  '/test_model-7/get',        req[:path]
        assert_equal( {:revision => 876}.to_json, req[:body] )
      end
    end
  end
end
