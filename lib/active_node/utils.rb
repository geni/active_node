module ActiveNode::Utils
  def self.extract_options(args)
    raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" if args.size > 1
    args.first || {}
  end

  def self.try(object, method, *args)
    object.send(method, *args) if object.respond_to?(method, true)
  end
end
