require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'pp'

$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
['deep_clonable', 'ordered_set'].each do |dir|
  $LOAD_PATH.unshift File.dirname(__FILE__) + "/../../#{dir}/lib"
end
require 'active_node'
require 'active_node/test_helper'
