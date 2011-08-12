require File.dirname(__FILE__) + '/../test_helper'

class Person < ActiveNode::Base
  has :best_friend,  :edge     => :best_friend
  has :friends,      :edges    => :friends
  has :aquaintences, :walk     => :friends_of_friends
  has :followers,    :incoming => :followed
end

class CollectionTest < Test::Unit::TestCase
  context 'An ActiveNode class' do
    context 'has class macro' do
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

      # has :aquaintences, :walk => :friends_of_friends
      should 'create collection using a walk' do
        meta = {
          "person-1" => {"path" => []},
          "person-8" => {"path" => []},
        }
        mock_active_node({"node_ids" => meta.keys.sort, "meta" => meta}) do |server|
          p = Person.init('person-42')

          assert_equal meta.keys.sort, p.aquaintences.node_ids.to_a
          assert_equal({"path" => []}, p.aquaintences["person-1"].meta)

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :read,                           req[:method]
          assert_equal '/person-42/friends-of-friends', req[:path]
        end
      end

      # has_many :followers, :incoming => :followed
      should 'create collection using incoming edges' do
        node_ids = [ "person-1", "person-8" ]

        mock_active_node({'followed' => {'incoming' => node_ids}}) do |server|
          p = Person.init('person-42')

          assert_equal node_ids, p.followers.node_ids.to_a
          assert_equal nil,      p.followers["person-1"].meta

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :read,                          req[:method]
          assert_equal '/person-42/incoming/followed', req[:path]
        end
      end
    end
  end

  context 'ActiveNode collection' do
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

  end # context 'ActiveNode collection'

end # class CollectionTest
