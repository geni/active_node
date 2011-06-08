require File.dirname(__FILE__) + '/../test_helper'

class TestHelperTest < Test::Unit::TestCase

  context 'TestHelper' do
    context 'mocked graph server' do

      should 'yield' do
        yielded = false
        mock_active_node do |server|
          yielded = true
        end
        assert_equal true, yielded
      end

      should 'let exceptions through' do
        assert_raise RuntimeError do
          mock_active_node do |server|
            raise 'ok!'
          end
        end
      end

      should 'allow mocking of errors' do
        assert_raise RuntimeError do
          mock_active_node_error(RuntimeError.new('foo'))
          ActiveNode.read_graph('foo')
        end
      end

    end
  end
end 
