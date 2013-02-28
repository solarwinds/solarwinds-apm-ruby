source 'https://rubygems.org'

# Import dependencies from oboe.gemspec
gemspec :name => 'oboe'

gem 'rake'

group :development do
  gem 'guard'
  gem 'guard-rspec'

  gem 'rb-inotify', :require => false
  gem 'rb-fsevent', :require => false
  gem 'rb-fchange', :require => false
end

group :test do
  gem 'rspec'

  # Instrumented gems
  gem 'dalli'
  gem 'memcache-client'
  gem 'memcached'
  gem 'cassandra'
  gem 'mongo'
  gem 'bson_ext' # For Mongo, Yours Truly
  gem 'moped'
  gem 'resque'
end

