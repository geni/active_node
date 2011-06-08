require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'pp'
require 'active_record'

$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
['deep_clonable', 'ordered_set'].each do |dir|
  $LOAD_PATH.unshift File.dirname(__FILE__) + "/../../#{dir}/lib"
end
require 'active_node'
require 'active_node/test_helper'

Mocha::Configuration.allow(:stubbing_method_unnecessarily)
Mocha::Configuration.prevent(:stubbing_non_existent_method)
