require "spec_helper"

describe "sieve of Eratosthenes" do

  # http://golang.org/doc/go_tutorial.html#tmp_353

  it "should work using Channel primitives" do

    # send the sequence 2,3,4, ... to returned channel
    def generate
      ch = channel!(:type => Integer)
      go!{ i = 1; loop { ch << i+= 1} }

      return ch
    end

    # filter out input values divisible by *prime*, send rest to returned channel
    def filter(in_channel, prime)
      out = channel!(:type => Integer)

      go! do
        loop do
          i, _ = in_channel.receive
          out << i if (i % prime) != 0
        end
      end

      return out
    end

    def sieve
      out = channel!(:type => Integer)

      go! do
        ch = generate
        loop do
          prime, _ = ch.receive
          out << prime
          ch = filter(ch, prime)
        end
      end

      return out
    end

    # run the sieve
    n = 20
    nth = false

    primes = sieve
    result = []

    if nth
      n.times { primes.receive }
      puts primes.receive[0]
    else
      loop do
        p, _ = primes.receive

        if p <= n
          result << p
        else
          break
        end
      end
    end

    result.should == [2,3,5,7,11,13,17,19]
  end

  it "should work with Ruby blocks" do

    # send the sequence 2,3,4, ... to returned channel
    generate = Proc.new do
      ch = channel!(:type => Integer)

      go! do
        i = 1
        loop { ch << i+= 1 }
      end

      ch
    end

    # filter out input values divisible by *prime*, send rest to returned channel
    filtr = Proc.new do |in_channel, prime|
      out = channel!(:type => Integer)

      go! do
        loop do
          i, _ = in_channel.receive
          out << i if (i % prime) != 0
        end
      end

      out
    end

    sieve = Proc.new do
      out = channel!(:type => Integer)

      go! do
        ch = generate.call

        loop do
          prime, _ = ch.receive
          out << prime
          ch = filtr.call(ch, prime)
        end
      end

      out
    end

    # run the sieve
    n = 20
    nth = false

    primes = sieve.call
    result = []

    if nth
      n.times { primes.receive }
      puts primes.receive[0]
    else
      loop do
        p, _ = primes.receive

        if p <= n
          result << p
        else
          break
        end
      end
    end

    result.should == [2,3,5,7,11,13,17,19]
  end
end
