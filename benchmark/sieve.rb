require 'benchmark'
project_lib_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
$LOAD_PATH.unshift(project_lib_path)
require 'agent'

$size = (ARGV.pop || 0).to_i

def generate(channels)
  ch = channel!(:type => Integer, :size => $size)
  channels << ch
  go!{ i = 1; loop { ch << i+= 1} }

  return ch
end

def filter(in_channel, prime, channels)
  out = channel!(:type => Integer, :size => $size)
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
  out = channel!(:type => Integer, :size => $size)
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

The command (except w/ ruby --1.9 for jruby):
  for i in {0..3};do ruby benchmark/sieve.rb $i; done

The results:

1. ruby 1.8.7 (2010-01-10 patchlevel 249) [universal-darwin11.0] (OSX Lion's ruby)

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive 28.540000   0.300000  28.840000 ( 28.758503)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive 26.630000   0.300000  26.930000 ( 26.868036)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive 26.720000   0.300000  27.020000 ( 26.945404)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive 26.490000   0.280000  26.770000 ( 26.711857)

2. ruby 1.9.2p318 (2012-02-14 revision 34678) [x86_64-darwin11.3.0]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive  6.860000   2.430000   9.290000 (  8.769513)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive  6.720000   2.130000   8.850000 (  8.397376)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive  6.870000   2.050000   8.920000 (  8.502869)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive  6.890000   1.990000   8.880000 (  8.479757)

3. ruby 1.9.3p125 (2012-02-16 revision 34643) [x86_64-darwin11.3.0]

150's prime, 5 goroutines, channel buffer size is 0
              user     system      total        real
receive   8.120000   5.380000  13.500000 ( 10.565193)

150's prime, 5 goroutines, channel buffer size is 1
              user     system      total        real
receive   7.810000   4.230000  12.040000 (  9.717816)

150's prime, 5 goroutines, channel buffer size is 2
              user     system      total        real
receive   7.590000   3.620000  11.210000 (  9.244201)

150's prime, 5 goroutines, channel buffer size is 3
              user     system      total        real
receive   8.050000   3.510000  11.560000 (  9.661748)

4. jruby 1.6.7 (ruby-1.8.7-p357) (2012-02-22 3e82bc8) (Java HotSpot(TM) 64-Bit Server VM 1.6.0_29) [darwin-x86_64-java]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive 10.538000   0.000000  10.538000 ( 10.508000)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive  9.901000   0.000000   9.901000 (  9.866000)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive  9.468000   0.000000   9.468000 (  9.434000)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive 11.278000   0.000000  11.278000 ( 11.242000)

5. jruby 1.6.7 (ruby-1.9.2-p312) (2012-02-22 3e82bc8) (Java HotSpot(TM) 64-Bit Server VM 1.6.0_29) [darwin-x86_64-java]

150's prime, 5 goroutines, channel buffer size is 0
             user     system      total        real
receive 10.986000   0.000000  10.986000 ( 10.986000)

150's prime, 5 goroutines, channel buffer size is 1
             user     system      total        real
receive 10.965000   0.000000  10.965000 ( 10.965000)

150's prime, 5 goroutines, channel buffer size is 2
             user     system      total        real
receive 12.303000   0.000000  12.303000 ( 12.304000)

150's prime, 5 goroutines, channel buffer size is 3
             user     system      total        real
receive 11.299000   0.000000  11.299000 ( 11.299000)
