require "minitest/autorun"
require "minitest/reporters"

ENV["RAILS_ENV"] = "test"
MiniTest::Reporters.use!

require 'rubygems'
require 'bundler'

Bundler.require(:default, :test)

# Preload memcache-client
require 'memcache'

Oboe::Ruby.initialize

