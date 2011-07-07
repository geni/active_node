require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'pp'
require 'active_record'

$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
require 'active_node'
require 'active_node/test_helper'

Mocha::Configuration.allow(:stubbing_method_unnecessarily)
Mocha::Configuration.prevent(:stubbing_non_existent_method)
