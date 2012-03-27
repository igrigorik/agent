#!/bin/bash

if [[ -s "$HOME/.rvm/scripts/rvm" ]] ; then

  # First try to load from a user install
  source "$HOME/.rvm/scripts/rvm"

elif [[ -s "/usr/local/rvm/scripts/rvm" ]] ; then

  # Then try to load from a root install
  source "/usr/local/rvm/scripts/rvm"

else

  printf "ERROR: An RVM installation was not found.\n"

fi

echo
echo `ruby -v`
echo
ruby benchmark/sieve.rb 0
ruby benchmark/sieve.rb 1
ruby benchmark/sieve.rb 2
ruby benchmark/sieve.rb 3
echo
rvm use 1.9.2
echo
echo `ruby -v`
echo
ruby benchmark/sieve.rb 0
ruby benchmark/sieve.rb 1
ruby benchmark/sieve.rb 2
ruby benchmark/sieve.rb 3
echo
rvm use 1.9.3
echo
echo `ruby -v`
echo
ruby benchmark/sieve.rb 0
ruby benchmark/sieve.rb 1
ruby benchmark/sieve.rb 2
ruby benchmark/sieve.rb 3
echo
rvm use jruby
echo
echo `ruby -v`
echo
ruby benchmark/sieve.rb 0
ruby benchmark/sieve.rb 1
ruby benchmark/sieve.rb 2
ruby benchmark/sieve.rb 3
echo
JRUBY_OPTS="--1.9"
echo `ruby -v`
echo
ruby benchmark/sieve.rb 0
ruby benchmark/sieve.rb 1
ruby benchmark/sieve.rb 2
ruby benchmark/sieve.rb 3
