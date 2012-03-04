# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "agent/version"

Gem::Specification.new do |s|
  s.name        = "agent"
  s.version     = Agent::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ilya Grigorik"]
  s.email       = ["ilya@igvita.com"]
  s.homepage    = "https://github.com/igrigorik/agent"
  s.summary     = %q{Agent is a diverse family of related approaches for modelling concurrent systems, in Ruby}
  s.description = s.summary

  s.rubyforge_project = "agent"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
