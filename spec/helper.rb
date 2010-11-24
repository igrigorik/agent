require 'timeout'
require 'rspec'
require 'yaml'

require 'lib/agent'

RSpec.configure do |c|
  c.filter_run_excluding :vm => lambda { |version|
    !(Config::CONFIG['ruby_install_name'] =~ /^#{version.to_s}/)
  }
end