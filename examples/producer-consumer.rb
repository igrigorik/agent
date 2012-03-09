require 'lib/agent'

c = channel!(:type => Integer)

go!(c) do |c|
  i = 0
  loop { c << i+= 1 }
end

p c.receive # => 1
p c.receive # => 2
