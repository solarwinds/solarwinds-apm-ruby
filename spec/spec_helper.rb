require 'rubygems'
require 'bundler'

Bundler.require(:default, :test)

RSpec.configure do |config|
  config.color_enabled = true
  config.formatter     = 'documentation'
end

Oboe::Ruby.initialize

