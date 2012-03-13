module ActiveNode::Utils
  def self.ensure_arity(args, max, min = 0)
    raise ArgumentError, "wrong number of arguments (#{args.size} for #{min})" if args.size < min
    raise ArgumentError, "wrong number of arguments (#{args.size} for #{max})" if args.size > max
  end

  def self.try(object, method, *args)
    object.send(method, *args) if object.respond_to?(method, true)
  end
end
