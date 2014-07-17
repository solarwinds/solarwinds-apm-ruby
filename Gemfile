source 'https://rubygems.org'

group :development, :test do
  gem 'minitest'
  gem 'minitest-reporters'
  gem 'rack-test'
  gem 'appraisal'
  gem 'bson'
end

group :development do
  gem 'ruby-debug',   :platform  => :mri_18
  gem 'debugger',     :platform  => :mri_19
  gem 'byebug',       :platforms => [ :mri_20, :mri_21 ]
  gem 'perftools.rb', :platforms => [ :mri_20, :mri_21 ], :require => 'perftools'
  gem 'pry'
end

# Instrumented gems
gem 'dalli'
gem 'memcache-client'
gem 'memcached', '1.7.2' if RUBY_VERSION < '2.0.0'
gem 'cassandra'
gem 'mongo'
gem 'bson_ext' # For Mongo, Yours Truly
gem 'moped', '~> 1.5' if RUBY_VERSION >= '1.9'
gem 'resque'
gem 'redis'

# Instrumented Frameworks
gem 'sinatra'

if RUBY_VERSION >= '1.9.3'
  gem 'padrino', '0.12.0'
  gem 'grape'
end

# Import dependencies from oboe.gemspec
gemspec :name => 'oboe'

