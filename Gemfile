source 'https://rubygems.org'

group :development, :test do
  gem 'minitest'
  gem 'minitest-reporters'
  gem 'rack-test'
  gem 'appraisal'
end

group :development do
  gem 'ruby-debug',   :platforms => [ :mri_18, :jruby ]
  gem 'debugger',     :platform  =>   :mri_19
  gem 'byebug',       :platforms => [ :mri_20, :mri_21 ]
  gem 'perftools.rb', :platforms => [ :mri_20, :mri_21 ], :require => 'perftools'
  gem 'pry'
end

# Instrumented gems
gem 'dalli'
gem 'memcache-client'
gem 'cassandra'
gem 'mongo'
gem 'moped' if RUBY_VERSION >= '1.9'
gem 'resque'
gem 'redis'
gem 'em-http-request'

unless defined?(JRUBY_VERSION)
  gem 'memcached', '1.7.2' if RUBY_VERSION < '2.0.0'
  gem 'bson_ext' # For Mongo, Yours Truly
end

# Instrumented Frameworks

if defined?(JRUBY_VERSION)
  gem 'sinatra', :require => false
else
  gem 'sinatra'
end

if RUBY_VERSION >= '1.9.3'
  gem 'padrino', '0.12.0'
  gem 'grape'
  gem 'bson'
else
  gem 'bson', '1.10.2'
end

gemspec

