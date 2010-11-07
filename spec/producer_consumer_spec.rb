require "helper"

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
      n.times do |i|
        c << i
        # puts "producer: #{i}"
      end

      s << "producer finished"
    end

    consumer = Proc.new do |c, n, s|
      n.times do |i|
        msg = c.receive
        # puts "consumer got: #{msg}"
      end

      s << "consumer finished"
    end

    c = Go::Channel.new(name: :c, type: Integer)
    s = Go::Channel.new(name: :s, type: String)

    go(c, 3, s, &producer)
    go(c, 3, s, &consumer)

    s.pop.should == "producer finished"
    s.pop.should == "consumer finished"

    c.close
    s.close
  end
end