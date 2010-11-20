module ActiveNode
  class TestServer
    attr_reader :requests

    def initialize(*mock_responses)
      @requests  = []
      @responses = mock_responses || []
    end

    def read(resource, params = nil)
      request(resource, :get, params)
    end

    def write(resource, data, params = nil)
      request(resource, :put, params, data)
    end

  private

    def request(resource, method, params, data = nil)
      opts = {
        :body   => data ? data.to_json : nil,
        :params => params,
        :method => method,
      }
      @requests << Typhoeus::Request.new(resource, opts)
      @responses.size > 1 ? @responses.shift : @responses.first
    end
  end

  module TestHelper
    def mock_active_node(*responses)
      server = ActiveNode::TestServer.new(*responses)
      ActiveNode.stubs(:server).returns(server)
      server
    end

    def mock_active_node_error(e)
      server = stub do 
        stubs(:write).raises(e)
      end
      ActiveNode.stubs(:server).returns(server)
      server
    end
  end
end
