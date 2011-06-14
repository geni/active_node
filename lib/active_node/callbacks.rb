module ActiveNode::Callbacks
  module ClassMethods
    def modify_add_attrs(attrs)
      # Called before add! is executed to modify attrs being passed in.
      attrs
    end

    def after_success(opts)
      # Called after an HTTP success response is received from an ActiveNode::Server.
    end

    def modify_read_params(params)
      # Called to allow modification of params before read_graph dispatches to ActiveNode::Server.
      params
    end

    def modify_write_params(params)
      # Called to allow modification of params before write_graph dispatches to ActiveNode::Server.
      params
    end

    def headers
      # Called from ActiveNode::Server to determine which headers send in the request.
      {}
    end
  end

  module InstanceMethods
    def modify_update_attrs(attrs)
      # Called before update! is executed to modify attrs being passed in.
      attrs
    end

    def after_update(response)
      # Called after update! is complete with the server response.
    end

    def after_add(response)
      # Called after add! is complete with the server response.
    end
  end
end
