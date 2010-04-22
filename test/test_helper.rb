require 'rubygems'
require 'test/unit'
require File.dirname(__FILE__) + '/../lib/active_node'
require 'shoulda'
require 'ostruct'
require 'pp'

class TestHTTP
  attr_reader :requests

  def self.create_response(code='200', body='')
    OpenStruct.new( :code => code, :body => body)
  end

  def initialize(mock_responses=nil)
    @requests  = []
    @responses = [mock_responses || self.class.create_response].flatten
  end

  [:get, :post].each do |method|
    define_method(method) do |resource, *args|
      (data, headers, extra_args) = args
      @requests << { :method     => method,
                     :resource   => resource,
                     :data       => data,
                     :headers    => headers,
                     :extra_args => extra_args }

      @responses.size > 1 ? @responses.shift : @responses.first
    end
  end
end

class TestModel < ActiveNode::Base
  def self.mock_server(responses=nil)
    ActiveNode.server(nil, nil).instance_variable_set(:@http, TestHTTP.new(responses))
  end
end
