module ActiveNode
  class TestServer < Server
    attr_reader :requests

    def initialize(*mock_responses)
      @host      = DEFAULT_HOST
      @requests  = []
      @responses = mock_responses || []
    end

  private

    def http(method, path, opts={})
      @requests << opts.merge(:method => method,
                              :path   => path,
                              :body   => opts[:data] ? opts[:data].to_json : nil)
      @responses.size > 1 ? @responses.shift : @responses.first
    end
  end

  module TestHelper
    def mock_active_node(*responses)
      server = ActiveNode::TestServer.new(*responses)
      ActiveNode.stubs(:server).returns(server)
      yield(server) if block_given?
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
