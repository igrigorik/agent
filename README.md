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
A simple multi-threaded consumer-producer, except without a thread or a mutex in sight! Note that by default Agent channels are unbuffered, meaning that the size is implicitly set to 0. Hence, in example below, the producer will generate a single value, and block until we call receive - rinse, repeat.

```ruby
c = channel!(Integer)

go! do
  i = 0
  loop { c << (i += 1) }
end

p c.receive.first # => 1
p c.receive.first # => 2
```

# Example: Multi-channel selector
A "select" statement chooses which of a set of possible communications will proceed. It looks similar to a "switch" statement but with the cases all referring to communication operations. Select will block until one of the channels becomes available:

```ruby
cw = channel!(Integer, 1)
cr = channel!(Integer, 1)

select do |s|
  s.case(cr, :receive) { |value| do_something(value) }
  s.case(cw, :send, 3)
end
```

In example above, cr is currently unavailable to read from (since its empty), but cw is ready for writing since the channel is buffered and empty. Hence, select will immediately choose the cw case and execute that code block.

```ruby
cr = channel!(Integer, 1)

select do |s|
  s.case(cr, :receive) { |value| do_something(value) }
  s.default            { puts :default }
end
```

In this example, cr is unavailable for read (since its empty), but we also provide "default" case which is executed immediately if no other cases are matched. In other words, no blocking.

```ruby
cr = channel!(Integer, 1)

select do |s|
  s.case(cr, :receive) { |value| do_something(value) }
  s.timeout(1.0)       { puts :timeout }
end
```

Once again, cr is empty, hence cannot be read from and there is no default block. Select will block until cr is readable or until the timeout condition is met - which in the case above is set to 1 second.

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

The MIT License - Copyright (c) 2011 Ilya Grigorik