source 'https://rubygems.org'

# Import dependencies from oboe.gemspec
gemspec :name => 'oboe'

gem 'rake'
gem 'appraisal'

group :development, :test do
  gem 'minitest'
  gem 'minitest-reporters'
end

# Instrumented gems
gem 'dalli'
gem 'memcache-client'
gem 'memcached' if (RUBY_VERSION =~ /^1./) == 0
gem 'cassandra'
gem 'mongo'
gem 'bson_ext' # For Mongo, Yours Truly
gem 'moped'
gem 'resque'

