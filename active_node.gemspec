lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "active_node"
  gem.version       = IO.read('VERSION')
  gem.authors       = ["Justin Balthrop"]
  gem.email         = ["git@justinbalthrop.com"]
  gem.description   = %q{Ruby client for memcached supporting advanced protocol features and pluggable architecture.}
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/ninjudd/active_node"

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'shoulda', '3.0.1'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'activerecord', '~> 2.3.9'

  gem.add_dependency 'curb'
  gem.add_dependency 'json'
  gem.add_dependency 'deep_hash'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
