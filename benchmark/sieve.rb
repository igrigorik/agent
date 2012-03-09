require 'benchmark'
require 'lib/agent'

def generate(num)
  ch = channel!(:type => Integer)
  go! { |i=1| loop { ch << i+= 1} }

  return ch
end

def filter(in_channel, prime, num)
  out = channel!(:type => Integer)

  go! do
    loop do
      i = in_channel.receive
      out << i if (i % prime) != 0
    end
  end

  return out
end

def sieve(num)
  out = channel!(:type => Integer)

  go! do
    ch = generate(num)
    loop do
      prime = ch.receive
      out << prime
      ch = filter(ch, prime, num)
    end
  end

  return out
end

################
################

nth_prime = 150
concurrency = 5

puts "#{nth_prime}'s prime, #{concurrency} goroutines"

Benchmark.bm do |x|
  x.report("receive") do
    runners = []

    concurrency.times do |n|
      runners << go! do
        primes = sieve(n)
        nth_prime.times { primes.receive }
      end
    end

    runners.map {|t| t.join}
  end
end

#
# ruby 1.9.2p0 (2010-08-18 revision 29036) [x86_64-darwin10.4.0]
#         user       system     total       real
# receive 15.200000  17.200000  32.400000 ( 25.582619)
#
# --------------
#
# jruby 1.5.2 (ruby 1.8.7 patchlevel 249) (2010-08-20 1c5e29d) (Java HotSpot(TM) 64-Bit Server VM 1.6.0_22) [x86_64-java]
#          user       system     total       real
# receive  9.435000   0.000000   9.435000 (  9.359000)
#