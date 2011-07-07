require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "active_node"
    gem.summary = %Q{Lightweight, restful resource wrapper.}
    gem.description = %Q{A very thin, restful resource wrapper specifically built with a Jiraph-based graph service in mind.}
    gem.email = "code@justinbalthrop.com"
    gem.homepage = "http://github.com/ninjudd/active_node"
    gem.authors = ["Justin Balthrop"]
    gem.add_dependency('ordered_set', '>= 1.0.0')
    gem.add_dependency('deep_hash',   '>= 0.0.1')
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new(:coverage) do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.rcov_opts = ['--text-report', '--exclude gems\/', '--sort coverage']
    test.verbose = true
  end
rescue LoadError
  task :coverage do
    abort "RCov is not available. In order to run rcov, you must: gem install rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "active_node #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
