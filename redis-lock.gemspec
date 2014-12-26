# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis-lock/version'

Gem::Specification.new do |gem|
  gem.name          = "pmckee11-redis-lock"
  gem.version       = Redis::Lock::VERSION
  gem.authors       = ["Peter McKee"]
  gem.email         = ["pmckee11@gmail.com"]
  gem.description   = %q{Distributed lock using ruby redis}
  gem.summary       = %q{Distributed lock using ruby redis}
  gem.homepage      = ""
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  
  gem.add_dependency "redis"
  gem.add_development_dependency "rspec"
end