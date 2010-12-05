# Agent

Agent is an attempt at [Go-like (CSP / pi-calculus) concurrency in Ruby](http://www.igvita.com/2010/12/02/concurrency-with-actors-goroutines-ruby/), but with an additional twist. It is a collection of different [process calculi](http://en.wikipedia.org/wiki/Process_calculus) primitives and patterns, with no specific, idiomatic affiliation to any specific implementation. A few available patterns so far:

 - Goroutines on top of green Ruby threads
 - Named, Typed, Bufferd and Unbufferred in-memory "channels"
 - Selectable "channels"

This gem is a work in progress, so treat it as such.

# Working Code Examples

 * [Producer, Consumer with Goroutines](https://github.com/igrigorik/agent/blob/master/spec/examples/producer_consumer_spec.rb)
 * [Serializable Channels / Event-driven server](https://github.com/igrigorik/agent/blob/master/spec/examples/channel_of_channels_spec.rb)
 * [Sieve of Eratosthenes](https://github.com/igrigorik/agent/blob/master/spec/examples/sieve_spec.rb)

# Example: Goroutine Generator
A simple multi-threaded consumer-producer, except without a thread or a mutex in sight!

    c = Agent::Channel.new(name: 'incr', type: Integer)

    go(c) do |c, i=0|
      loop { c << i+= 1 }
    end

    p c.receive # => 1
    p c.receive # => 2

# Example: Multi-channel selector
A "select" statement chooses which of a set of possible communications will proceed. It looks similar to a "switch" statement but with the cases all referring to communication operations. Select will block until one of the channels becomes available:

    cw = Agent::Channel.new(:name => "select-write", :type => Integer, :size => 1)
    cr = Agent::Channel.new(:name => "select-read",  :type => Integer, :size => 1)

    select do |s|
      s.case(cr, :receive) { |c| c.receive }
      s.case(cw, :send)    { |c| c.send 3  }
      s.default            { puts :default }
    end

In example above, cr is currently unavailable to read from (since its empty), but cw is ready for writing. Hence, select will immediately choose the cw case and execute that code block. If both channels were unavailable for immediate processing, then the default block would fire. If you omit the default block, and both channels are unavailable then select will wait until one of the channels is ready and execute your code at that time.

# Go & π-calculus: Background & Motivation

*Do not communicate by sharing memory; instead, share memory by communicating.*

See [Concurrency with Actors, Goroutines & Ruby](http://www.igvita.com/2010/12/02/concurrency-with-actors-goroutines-ruby/) for motivation and comparison to other concurrency models.

Concurrent programming in many environments is made difficult by the subtleties required to implement correct access to shared variables. Google's Go encourages a different approach in which shared values are passed around on channels and, in fact, never actively shared by separate threads of execution. Only one goroutine has access to the value at any given time. Data races cannot occur, by design.

One way to think about this model is to consider a typical single-threaded program running on one CPU. It has no need for synchronization primitives. Now run another such instance; it too needs no synchronization. Now let those two communicate; if the communication is the synchronizer, there's still no need for other synchronization. Unix pipelines, for example, fit this model perfectly. Although Go's approach to concurrency originates in Hoare's Communicating Sequential Processes (CSP), it can also be seen as a type-safe generalization of Unix pipes.

To learn more about Go see following resources:

 * [golang.org](http://golang.org/)
 * [Go's concurrency](http://golang.org/doc/effective_go.html#concurrency)
 * [Go's channels](http://golang.org/doc/effective_go.html#channels)
 * [Go's select statement](http://golang.org/doc/go_spec.html#Select_statements)

# License

(The MIT License)

Copyright (c) 2010 Ilya Grigorik

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.