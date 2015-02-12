require "spec_helper"

describe "Producer-Consumer" do
  it "should synchronize by communication" do

    #     func producer(c chan int, N int, s chan bool) {
    #       for i := 0; i < N; i++ {
    #         fmt.Printf("producer: %d\n", i)
    #         c <- i
    #       }
    #       s <- true
    #     }
    #
    #     func consumer(c chan int, N int, s chan bool) {
    #       for i := 0; i < N; i++ {
    #         fmt.Printf("consumer got: %d\n", <- c)
    #       }
    #       s <- true
    #     }
    #
    #     func main() {
    #       runtime.GOMAXPROCS(2)
    #
    #       c := make(chan int)
    #       s := make(chan bool)
    #
    #       go producer(c, 10, s)
    #       go consumer(c, 10, s)
    #
    #       <- s
    #       <- s
    #     }

    producer = Proc.new do |c, n, s|
      # print "producer: starting\n"

      n.times do |i|
        # print "producer: #{i+1} of #{n}\n"
        c << i
        # print "producer sent: #{i}\n"
      end

      # print "producer: finished\n"

      s << "producer finished"
    end

    consumer = Proc.new do |c, n, s|
      # print "consumer: starting\n"
      n.times do |i|
        # print "consumer: #{i+1} of #{n}\n"
        msg = c.receive
        # print "consumer got: #{msg}\n"
      end

      # print "consumer: finished\n"

      s << "consumer finished"
    end

    c = channel!(Integer)
    s = channel!(String)

    go!(c, 3, s, &producer)
    sleep 0.1
    go!(c, 3, s, &consumer)

    messages = [s.pop[0], s.pop[0]]
    expect(messages).to include("producer finished")
    expect(messages).to include("consumer finished")

    c.close
    s.close
  end

  it "should work as generator" do
    producer = Proc.new do |c|
      i = 0
      loop { c.pipe << i+= 1 }
    end

    Generator = Struct.new(:name, :pipe)
    c = channel!(Integer)
    g = Generator.new(:incr, c)

    go!(g, &producer)

    expect(c.receive[0]).to eq(1)
    expect(c.receive[0]).to eq(2)
    expect(c.receive[0]).to eq(3)
    c.close
  end
end