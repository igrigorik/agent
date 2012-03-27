require 'benchmark'
project_lib_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
$LOAD_PATH.unshift(project_lib_path)
require 'agent'

$size = (ARGV.pop || 0).to_i

def generate(channels)
  ch = channel!(Integer, $size)
  channels << ch
  go!{ i = 1; loop { ch << i+= 1} }

  return ch
end

def filter(in_channel, prime, channels)
  out = channel!(Integer, $size)
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
  out = channel!(Integer, $size)
  channels << out

  go! do
    ch = generate(channels)
    loop do
      prime, _ = ch.receive
      out << prime
      ch = filter(ch, prime, channels)
    end
  end

  return out
end

################
################

nth_prime = 150
concurrency = 5
channels = []

puts "#{nth_prime}'s prime, #{concurrency} goroutines, channel buffer size is #{$size}"

Benchmark.bm(7) do |x|
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

puts

channels.each(&:close)

__END__

The setup:
  13" Macbook Air
  OSX Lion 10.7.3
  1.8 GHz Intel Core i7
  4 GB 1333 MHz DDR3
  SSD
  Terminal w/ OSX Lion's system ruby by default

The command:
  benchmark/multi_ruby_bench.sh

The results:

ruby 1.8.7 (2010-01-10 patchlevel 249) [universal-darwin11.0]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive 27.100000   0.290000  27.390000 ( 27.324909)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive 24.690000   0.280000  24.970000 ( 24.910035)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive 24.730000   0.280000  25.010000 ( 24.946830)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive 25.010000   0.290000  25.300000 ( 25.238002)


ruby 1.9.2p318 (2012-02-14 revision 34678) [x86_64-darwin11.3.0]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive  5.410000   2.360000   7.770000 (  7.241433)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive  5.270000   1.980000   7.250000 (  6.817536)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive  5.330000   2.030000   7.360000 (  6.918912)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive  5.340000   1.950000   7.290000 (  6.864300)


ruby 1.9.3p125 (2012-02-16 revision 34643) [x86_64-darwin11.3.0]

150's prime, 5 goroutines, channel buffer size is 0
              user     system      total        real
receive   6.470000   5.220000  11.690000 (  8.803085)

150's prime, 5 goroutines, channel buffer size is 1
              user     system      total        real
receive   6.390000   4.190000  10.580000 (  8.248593)

150's prime, 5 goroutines, channel buffer size is 2
              user     system      total        real
receive   6.240000   3.760000  10.000000 (  7.936199)

150's prime, 5 goroutines, channel buffer size is 3
              user     system      total        real
receive   6.000000   3.200000   9.200000 (  7.461371)


jruby 1.6.7 (ruby-1.8.7-p357) (2012-02-22 3e82bc8) (Java HotSpot(TM) 64-Bit Server VM 1.6.0_29) [darwin-x86_64-java]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive  9.672000   0.000000   9.672000 (  9.637000)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive 12.528000   0.000000  12.528000 ( 12.494000)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive 13.191000   0.000000  13.191000 ( 13.150000)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive 14.702000   0.000000  14.702000 ( 14.668000)


jruby 1.6.7 (ruby-1.8.7-p357) (2012-02-22 3e82bc8) (Java HotSpot(TM) 64-Bit Server VM 1.6.0_29) [darwin-x86_64-java]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive  9.869000   0.000000   9.869000 (  9.836000)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive 12.399000   0.000000  12.399000 ( 12.362000)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive 13.146000   0.000000  13.146000 ( 13.154000)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive 13.888000   0.000000  13.888000 ( 13.847000)


rubinius 1.2.4 (1.8.7 release 2011-07-05 JI) [x86_64-apple-darwin11.3.0]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive 20.890472   3.099183  23.989655 ( 19.765032)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive 21.727269   3.028753  24.756022 ( 20.554911)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive 45.912357   5.814811  51.727168 ( 44.636344)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive 46.211119   7.487593  53.698712 ( 44.716384)


rubinius 2.0.0dev (1.8.7 65c6146e yyyy-mm-dd JI) [x86_64-apple-darwin11.3.0]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive 62.980970   4.578037  67.559007 ( 18.560938)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive 52.822284   4.667321  57.489605 ( 15.986046)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive 54.217875   4.579821  58.797696 ( 16.267339)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive 59.092219   4.881411  63.973630 ( 17.664269)
