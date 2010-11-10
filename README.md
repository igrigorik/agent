# Agent

Agent is a diverse family of related approaches to formally modelling concurrent systems, in Ruby. In other words, it is a collection of different [process calculi](http://en.wikipedia.org/wiki/Process_calculus) primitives and patterns, with no specific, idiomatic affiliation to any specific implementation. A few available patterns so far:

 - Goroutines on top of green Ruby threads
 - Named, in-memory channels

This gem is a work in progress & an experiment, so treat it as such. At the moment, it is heavily influenced by Google's Go and π-calculus primitives.

# Go & π-calculus: Background & Motivation

*Do not communicate by sharing memory; instead, share memory by communicating.*

Concurrent programming in many environments is made difficult by the subtleties required to implement correct access to shared variables. Google's Go encourages a different approach in which shared values are passed around on channels and, in fact, never actively shared by separate threads of execution. Only one goroutine has access to the value at any given time. Data races cannot occur, by design.

One way to think about this model is to consider a typical single-threaded program running on one CPU. It has no need for synchronization primitives. Now run another such instance; it too needs no synchronization. Now let those two communicate; if the communication is the synchronizer, there's still no need for other synchronization. Unix pipelines, for example, fit this model perfectly. Although Go's approach to concurrency originates in Hoare's Communicating Sequential Processes (CSP), it can also be seen as a type-safe generalization of Unix pipes.

To learn more about Go see following resources:

 * [golang.org](http://golang.org/)
 * [Go's concurrency](http://golang.org/doc/effective_go.html#concurrency)
 * [Go's channels](http://golang.org/doc/effective_go.html#channels)


# Example: Goroutine Generator

    producer = Proc.new do |c|
      puts "Starting generator: #{c.name}"

      i = 0
      loop { c.pipe << i+= 1 }
    end

    c = Go::Channel.new(name: :incr, type: Integer)

    Generator = Struct.new(:name, :pipe)
    g = Generator.new(:incr, c)

    go(g, &producer)

    c.receive
    c.receive

# License

(The MIT License)

Copyright (c) 2010 Ilya Grigorik

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.