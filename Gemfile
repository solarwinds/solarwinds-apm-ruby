source 'https://rubygems.org'

group :development, :test do
  gem 'minitest'
  gem 'minitest-reporters'
  gem 'rack-test'
  gem 'appraisal'
  gem 'bson'
end

group :development do
  gem 'ruby-debug',   :platform => :mri_18
  gem 'ruby-debug19', :platform => :mri_19, :require => 'ruby-debug'
  gem 'byebug',       :platform => :mri_20 
  gem 'perftools.rb', :platform => :mri,    :require => 'perftools'
  gem 'pry'
end

# Instrumented gems
gem 'dalli'
gem 'memcache-client'
gem 'memcached' if RUBY_VERSION < '2.0.0'
gem 'cassandra'
gem 'mongo'
gem 'bson_ext' # For Mongo, Yours Truly
gem 'moped' if RUBY_VERSION >= '1.9'
gem 'resque'
gem 'redis'

# Instrumented Frameworks
gem 'sinatra'

if RUBY_VERSION >= '1.9.3'
  gem 'padrino', '0.12.0' 
end

# Import dependencies from oboe.gemspec
gemspec :name => 'oboe'

