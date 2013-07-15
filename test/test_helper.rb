require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha/setup'
require 'pp'
require 'active_record'

$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../plugins/rupture/lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../deep_clonable/lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../ordered_set/lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
require 'active_node'
require 'active_node/test_helper'

Mocha::Configuration.allow(:stubbing_method_unnecessarily)
Mocha::Configuration.prevent(:stubbing_non_existent_method)
