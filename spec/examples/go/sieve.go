// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
  "flag"
  "fmt"
  "os"
  "strconv"
)

var nth = flag.Bool("n", false, "print the nth prime only")

// Send the sequence 2, 3, 4, ... to returned channel
func generate() chan int {
  ch := make(chan int)
  go func() {
    for i := 2; ; i++ {
      ch <- i
    }
  }()
  return ch
}

// Filter out input values divisible by 'prime', send rest to returned channel
func filter(in chan int, prime int) chan int {
  out := make(chan int)
  go func() {
    for {
      if i := <-in; i%prime != 0 {
        out <- i
      }
    }
  }()
  return out
}

func sieve() chan int {
  out := make(chan int)
  go func() {
    ch := generate()
    for {
      prime := <-ch
      out <- prime
      ch = filter(ch, prime)
    }
  }()
  return out
}

func main() {
  flag.Parse()
  n, err := strconv.Atoi(flag.Arg(0))
  if err != nil {
    fmt.Fprintf(os.Stderr, "bad argument\n")
    os.Exit(1)
  }
  primes := sieve()
  if *nth {
    for i := 1; i < n; i++ {
      <-primes
    }
    fmt.Println(<-primes)
  } else {
    for {
      p := <-primes
      if p <= n {
        fmt.Println(p)
      } else {
        return
      }
    }
  }
}
