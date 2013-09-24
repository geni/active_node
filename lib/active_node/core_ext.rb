class String
  # Add underscore and camelize methods if they aren't there. Copied from ActiveSupport::Inflector
  def underscore
    self.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").downcase
  end unless instance_methods.include?('underscore')

  def camelize(*args)
    gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
  end unless instance_methods.include?('camelize')

  def constantize
    constant = Object
    split('::').each do |name|
      constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
    end
    constant
  end unless instance_methods.include?('constantize')
end
