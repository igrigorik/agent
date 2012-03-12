require 'benchmark'
project_lib_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
$LOAD_PATH.unshift(project_lib_path)
require 'agent'

def generate(channels)
  ch = channel!(:type => Integer)
  channels << ch
  go!{ i = 1; loop { ch << i+= 1} }

  return ch
end

def filter(in_channel, prime, channels)
  out = channel!(:type => Integer)
  channels << out

  go! do
    loop do
      i, _ = in_channel.receive
      out << i if (i % prime) != 0
    end
  end

  return out
end

def sieve(channels)
  out = channel!(:type => Integer)
  channels << out

  go! do
    ch = generate(channels)
    loop do
      prime, _ = ch.receive
      out << prime
      ch = filter(ch, prime, channels)
      channels << ch
    end
  end

  return out
end

################
################

nth_prime = 150
concurrency = 5
channels = []

puts "#{nth_prime}'s prime, #{concurrency} goroutines"

Benchmark.bm do |x|
  x.report("receive") do
    runners = []

    concurrency.times do |n|
      runners << go! do
        primes = sieve(channels)
        nth_prime.times { primes.receive }
      end
    end

    runners.map {|t| t.join}
  end
end

channels.each(&:close)

#       (osx lion's) ruby 1.8.7-p249 - 79.6s (omg)
#                    ruby 1.9.2-p318 - 10.1s
#                    ruby 1.9.3-p125 - 11.4s
# (1.8.7-p357 w/o --1.9) jruby 1.6.7 - 16.4s
#   (1.8.7-p357 w --1.9) jruby 1.6.7 - 13.4s
