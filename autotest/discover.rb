Autotest.add_discovery { 'rspec2' }

if RUBY_PLATFORM =~ /java/
  Autotest.add_hook :initialize do |at|
    def at.ruby
      "#{super} --1.9"
    end
  end
end