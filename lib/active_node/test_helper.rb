module ActiveNode
  class TestServer < Server
    attr_reader :requests

    def initialize(*mock_responses)
      @host      = DEFAULT_HOST
      @requests  = []
      @responses = mock_responses || []
    end

    def set_host!(host)
      @host = host
      self
    end

  private

    def http(opts)
      @requests << opts.merge(:method => opts[:method],
                              :path   => path_with_context(opts[:path]),
                              :body   => opts[:data] ? opts[:data].to_json : nil)
      @responses.size > 1 ? @responses.shift : @responses.first
    end

    def path_with_context(path)
      (hostname, context) = host.to_s.split(/\//, 2)
      return path if context.to_s.blank?
      context += '/' unless path.starts_with?('/')
      "/#{context}#{path}"
    end
  end

  module TestHelper
    def mock_active_node(*responses)
      server = ActiveNode::TestServer.new(*responses)

      ActiveNode::Server.stubs(:init).with do |host|
        server.set_host!(host)
      end.returns(server)

      yield(server) if block_given?
      server
    end

    def mock_active_node_error(e)
      mock_active_node do |server|
        server.stubs(:write).raises(e)
        server.stubs(:read).raises(e)
        return server
      end
    end
  end
end

Test::Unit::TestCase.send :include, ActiveNode::TestHelper
