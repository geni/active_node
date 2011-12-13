require File.dirname(__FILE__) + '/../test_helper'

class Person < ActiveNode::Base
  has :best_friend,  :edge     => :best_friend, :predicate => :bff?
  has :friends,      :edges    => :friends
  has :aquaintences, :walk     => :friends_of_friends, :count => :foaf_count
  has :followers,    :incoming => :followed, :predicate => true
  has :mentor
  has :deity, :attr => :god
  has :robots
end

class Robot < ActiveNode::Base; end

class CollectionTest < Test::Unit::TestCase
  def setup
    Person.reset
  end

  context 'An ActiveNode class' do
    context 'has class macro' do
      # has :best_friend, :edge => :best_friend
      should 'create collection using edge' do
        mock_active_node({'best-friend' => {'edges' => {'person-1' => {'since' => 1998}}}}) do |server|
          p = Person.init('person-42')

          assert_equal 'person-1', p.best_friend.node_id
          assert_equal 1998,       p.best_friend.meta['since']
          assert  p.bff?('person-1')
          assert !p.bff?('person-2')
          assert  p.bff?(ActiveNode.init('person-1'))
          assert !p.bff?(ActiveNode.init('person-2'))
          assert !p.bff?(nil)

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :read,                          req[:method]
          assert_equal '/person-42/edges/best-friend', req[:path]
        end
      end

      # has :friends, :edges => :friends
      should 'create collection using edges' do
        edges = {
          "person-1" => {"context" => "UNM"},
          "person-8" => {"context" => "shopzilla"},
        }

        mock_active_node({'friends' => {'edges' => edges}}) do |server|
          p = Person.init('person-42')

          assert_equal edges.keys.sort,      p.friends.node_ids.to_a
          assert_equal({"context" => "UNM"}, p.friends["person-1"].meta)

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :read,                      req[:method]
          assert_equal '/person-42/edges/friends', req[:path]
        end
      end

      # has :aquaintences, :walk => :friends_of_friends, :count => :foaf_count
      should 'create collection using a walk' do
        meta = {
          "person-1" => {"path" => []},
          "person-8" => {"path" => []},
        }
        mock_active_node({"node_ids" => meta.keys.sort, "meta" => meta, "count" => 42}) do |server|
          p = Person.init('person-42')
          coll = p.aquaintences(:limit => 2)

          assert_equal meta.keys.sort, coll.node_ids.to_a
          assert_equal({"path" => []}, coll["person-1"].meta)
          assert_equal 42,             coll.count
          assert_equal 2,              coll.size

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :read,                           req[:method]
          assert_equal '/person-42/friends-of-friends', req[:path]
        end
      end

      # has :followers, :incoming => :followed
      should 'create collection using incoming edges' do
        node_ids = [ "person-1", "person-8" ]

        mock_active_node({'followed' => {'incoming' => node_ids}}) do |server|
          p = Person.init('person-42')

          assert_equal node_ids, p.followers.node_ids.to_a
          assert_equal nil,      p.followers["person-1"].meta
          assert  p.follower?('person-1')
          assert !p.follower?('person-2')

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :read,                          req[:method]
          assert_equal '/person-42/incoming/followed', req[:path]
        end
      end

      # has :friends, :edges => :friends
      should 'create count method' do
        mock_active_node({'friends' => {'edges' => 42}}) do |server|
          assert_equal 42, Person.init('person-42').friend_count

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :read,                      req[:method]
          assert_equal '/person-42/edges/friends', req[:path]
          assert_equal true,                       req[:params][:count]
        end
      end

      # has :aquaintences, :walk => :friends_of_friends, :count => :foaf_count
      should 'create custom count method' do
        mock_active_node({'count' => 111}) do |server|
          assert_equal 111, Person.init('person-42').foaf_count

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :read,                           req[:method]
          assert_equal '/person-42/friends-of-friends', req[:path]
          assert_equal true,                            req[:params][:count]
        end
      end

      schema = {
        'mentor' => {'a' => {}},
        'god'    => {'a' => {}},
        'robots' => {'a' => {}}
      }
      data = [{
        'id'       => 'person-42',
        'revision' => 1337,
        'a'        => {'mentor' => 'person-1',
                       'god'    => 'person-2',
                       'robots' => ['robot-1', 'robot-2']},
      }]

      # has :mentor
      # has :robots
      # has :deity, :attr => :god
      should 'return an active node' do
        mock_active_node(schema, data) do |server|
          p = Person.init('person-42')

          assert_equal 'person-1', p.mentor.node_id
          assert_equal 'person-2', p.deity.node_id
          assert_equal 'person-2', p.god

          assert_equal ["robot-1", "robot-2"], p.robots.collect {|r| r.node_id}
        end
      end
    end
  end

  context 'ActiveNode collection' do
    NODE_IDS = ['person-1', 'robot-1', 'person-2']

    should 'fetch revisions by layer' do
      revisions43 = {
        "id" => "person-43",
        "foo" => {"revisions" => [1, 2, 3]},
        "bar" => {"revisions" => [3, 4, 5]},
      }
      revisions42 = {
        "id" => "person-42",
        "foo" => {"revisions" => [12, 13, 14]},
        "bar" => {"revisions" => [13, 14, 15]},
      }
      mock_active_node([revisions43, revisions42]) do |server|
        p = ActiveNode::Collection.new(['person-42', 'person-43'])

        assert_equal({"foo"=>[12, 13, 14], "bar"=>[13, 14, 15]}, p[0].revisions(['foo', 'bar']))
        assert_equal({"foo"=>[1, 2, 3],    "bar"=>[3, 4, 5]},    p[1].revisions(['foo', 'bar']))
      end
    end

    should 'not fail when no data is returned' do
      mock_active_node({}) do |server|
        assert_equal nil, Person.init(1).best_friend
        assert_equal [],  Person.init(1).friends.to_a
        assert_equal [],  Person.init(1).followers.to_a
      end
    end

    context '[] method' do
      context 'with string parameter' do
        should 'return nil if absent' do
          assert_nil ActiveNode::Collection.new(['person-1', 'person-2'])['person-42']
        end
      end # context 'with string parameter'
    end # context '[] method'

    context 'node_ids method' do

      context 'with no parameter' do

        should 'return all node_ids' do
          assert_equal NODE_IDS, ActiveNode::Collection.new(NODE_IDS).node_ids.to_a
        end

      end # context 'with no parameter'

      context 'with matching type parameter' do

        should 'return matching node_ids' do
          collection = ActiveNode::Collection.new(NODE_IDS)
          assert_equal ['person-1', 'person-2'], collection.node_ids('person').to_a
          assert_equal ['robot-1'],              collection.node_ids('robot').to_a
        end

      end # context 'with matching type parameter'

      context 'with non-matching type parameter' do

        should 'return no node_ids' do
          assert_equal [], ActiveNode::Collection.new(NODE_IDS).node_ids('bad').to_a
        end

      end # context 'with non-matching type parameter'

    end # context 'node_ids method'

    context 'each method' do

      context 'with no parameter' do

        should 'loop through all nodes' do
          results = []
          ActiveNode::Collection.new(NODE_IDS).each do |node|
            results << node.node_id
          end
          assert_equal NODE_IDS, results
        end

      end # context 'with no parameter'

      context 'with matching type parameter' do

        should 'loop through some nodes' do
          collection = ActiveNode::Collection.new(NODE_IDS)

          results = []
          collection.each('person') do |node|
            results << node.node_id
          end
          assert_equal ['person-1', 'person-2'], results

          results = []
          collection.each('robot') do |node|
            results << node.node_id
          end
          assert_equal ['robot-1'], results
        end

      end # context 'with matching type parameter'

      context 'with non-matching type parameter' do

        should 'return no node_ids' do
          results = []
          ActiveNode::Collection.new(NODE_IDS).each('bad') do |node|
            results << node.node_id
          end
          assert_equal [], results
        end

      end # context 'with non-matching type parameter'


    end # context 'each method'

  end # context 'ActiveNode collection'

end # class CollectionTest
