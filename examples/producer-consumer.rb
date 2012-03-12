project_lib_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
$LOAD_PATH.unshift(project_lib_path)
require 'agent'

c = channel!(:type => Integer)

go!(c) do |c|
  i = 0
  loop { c << i+= 1 }
end

p c.receive[0] # => 1
p c.receive[0] # => 2

c.close
