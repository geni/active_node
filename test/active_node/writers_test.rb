require_relative '../test_helper'

class Person < ActiveNode::Base
  writers :delete!, :undelete!, :tag!, :add_friend!
end

class WritersTest < Test::Unit::TestCase

  def setup
    Person.reset
  end

  context 'An ActiveNode model' do

    context 'writers' do

      should 'call write_graph' do
        mock_active_node({}) do |server|
          p = Person.init('person-1')

          assert_equal p, p.delete!

          req = server.requests.shift
          assert_equal :write,               req[:method]
          assert_equal '/person-1/delete',   req[:path]

          assert_equal p, p.undelete!('user' => 'user-3')

          req = server.requests.shift
          assert_equal :write,               req[:method]
          assert_equal '/person-1/undelete', req[:path]
          assert_equal({'user' => 'user-3'}, req[:data])

          assert_equal p, p.tag!('photo-1')

          req = server.requests.shift
          assert_equal :write,              req[:method]
          assert_equal '/person-1/tag',     req[:path]
          assert_equal({'id' => 'photo-1'}, req[:data])

          assert_equal p, p.add_friend!(Person.init('person-2'))

          req = server.requests.shift
          assert_equal :read,            req[:method]
          assert_equal '/person/schema', req[:path]
 
          req = server.requests.shift
          assert_equal :write,                 req[:method]
          assert_equal '/person-1/add-friend', req[:path]
          assert_equal({'id' => 'person-2'},   req[:data])
        end
      end

    end # context 'writers'

  end # context 'An ActiveNode model'

end # WritersTest
