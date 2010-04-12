require File.dirname(__FILE__) + '/test_helper'

class ActiveNodeTest < Test::Unit::TestCase
  context "An ActiveNode class" do
    should "send attributes as JSON body on PUT" do
      server = TestModel.mock_server

      TestModel.PUT('add', { :name => 'Harley' })

      assert_equal 1, server.requests.size
      req = server.requests.shift

      assert_equal  :put,                         req[:method]
      assert_equal  '/test_model/add',            req[:resource]
      assert_equal( {'name' => 'Harley'}.to_json, req[:data])
      assert_equal  'application/json',           req[:headers]['Content-type']
    end
  end

  context "An ActiveNode model" do
    should "set @node_id in init" do
      t = TestModel.init('model-43')
      assert_equal 'model-43', t.instance_variable_get(:@node_id)
    end

    should "set @layer_data in init" do
      t = TestModel.init( 'test_model' => {:name => 'Charlie', 'occupation' => 'chocolate maker'} )
      
      layer_data = t.instance_variable_get(:@layer_data)
      assert_not_nil layer_data
      assert_equal [:test_model],     layer_data.keys
      assert_equal 'Charlie',         layer_data[:test_model][:name]
      assert_equal 'chocolate maker', layer_data[:test_model]['occupation']
    end

    should "send attributes as JSON body on POST" do
      server = TestModel.mock_server
      TestModel.init('test_model-1').POST('update', { :name => 'Charlie' })

      assert_equal 1, server.requests.size
      req = server.requests.shift

      assert_equal  :post,                         req[:method]
      assert_equal  '/test_model-1/update',        req[:resource]
      assert_equal( {'name' => 'Charlie'}.to_json, req[:data])
      assert_equal  'application/json',            req[:headers]['Content-type']
    end

    should "GET all attributes when called with no resource" do
      server = TestModel.mock_server
      TestModel.init('test_model-1').GET('')

      assert_equal 1, server.requests.size
      req = server.requests.shift

      assert_equal  :get,             req[:method]
      assert_equal  '/test_model-1/', req[:resource]
    end

    should "GET specified attributes when called with resource" do
      server = TestModel.mock_server
      TestModel.init('test_model-1').GET('profile')

      assert_equal 1, server.requests.size
      req = server.requests.shift

      assert_equal  :get,                    req[:method]
      assert_equal  '/test_model-1/profile', req[:resource]
    end
    
    should 'pass user-specified headers' do
      server = TestModel.mock_server
      TestModel.init('test_model-1').POST('update', { :name => 'Bob' }, { 'X-Test-Headers' => 'testing' })

      assert_equal 1, server.requests.size
      req = server.requests.shift

      assert_equal  'testing', req[:headers]['X-Test-Headers']
    end
  end
end