require File.dirname(__FILE__) + '/../test_helper'

class Person < ActiveNode::Base
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

        # has :friends, :edges => :friends
        mock_active_node({"node_ids" => edges.keys.sort, "meta" => edges}) do |server|
          p = Person.init('person-42')

          assert_equal edges.keys.sort,      p.friends.node_ids.to_a
          assert_equal({"context" => "UNM"}, p.friends["person-1"].meta)

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :get,                       req[:method]
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

          assert_equal :get,                            req[:method]
          assert_equal '/person-42/friends-of-friends', req[:path]
        end
      end

      # has_many :followers, :incoming => :followed
      should 'create collection using incoming edges' do
        node_ids = [ "person-1", "person-8" ]

        mock_active_node({"node_ids" => node_ids}) do |server|
          p = Person.init('person-42')

          assert_equal node_ids, p.followers.node_ids.to_a
          assert_equal nil,      p.followers["person-1"].meta

          assert_equal 1, server.requests.size
          req = server.requests.shift

          assert_equal :get,                           req[:method]
          assert_equal '/person-42/incoming/followed', req[:path]
        end
      end

    end

  end

end # class CollectionTest
