require 'timeout'
require 'rspec'
require 'yaml'

$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
require 'agent'

RSpec.configure do |c|
  c.filter_run_excluding :vm => lambda { |version|
    !(Config::CONFIG['ruby_install_name'] =~ /^#{version.to_s}/)
  }
end
