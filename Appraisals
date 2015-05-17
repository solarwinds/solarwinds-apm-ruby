appraise "rails23" do
  gem "rails", "~>2.3"
end

appraise "rails32" do
  gem "rails", "~>3.2"
end

appraise "rails40" do
  gem "rails", "~>4.0"
end

appraise "padrino" do
  gem 'padrino'
end

appraise "grape" do
  gem 'grape'
end

appraise "libraries" do
  # Instrumented gems
  gem 'dalli'
  gem 'memcache-client'
  gem 'cassandra'
  gem 'mongo'
  gem 'resque'
  gem 'redis'
  gem 'faraday'
  gem 'httpclient'
  gem 'excon'
  gem 'typhoeus'
  gem 'sequel'
  if RUBY_VERSION >= '1.9.3'
    # rest-client depends on mime-types gem which only supports
    # ruby 1.9.3 and up
    gem 'rest-client'
  end

  # Database adapter gems needed by sequel
  if defined?(JRUBY_VERSION)
    gem 'jdbc-postgresql'
    gem 'jdbc-mysql'
  else
    gem 'mysql'
    gem 'mysql2'
    if RUBY_VERSION < '1.9.3'
      gem 'pg', '0.17.1'
    else
      gem 'pg'
    end
  end

  if RUBY_VERSION >= '1.9'
    gem 'moped'
    gem 'eventmachine'
    gem 'em-synchrony'
    gem 'em-http-request'
  end

  unless defined?(JRUBY_VERSION)
    gem 'memcached', '1.7.2' if RUBY_VERSION < '2.0.0'
    gem 'bson_ext' # For Mongo, Yours Truly
  end
end
# vim:syntax=ruby
