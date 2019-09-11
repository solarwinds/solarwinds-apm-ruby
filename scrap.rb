# Gemfile
#
# source "https://rubygems.org"
#
# gem 'rails', '~> 6.0.0'
# gem 'puma'
# gem 'pg'



require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

require 'rack/handler/puma'


# adjust this or comment out if you have a config/database.yml
ENV['DATABASE_URL'] = "postgresql://docker:#{ENV['DOCKER_PSQL_PASS']}@127.0.0.1:5432/travis_ci_test"
ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])


module Rails50APIStack
  class Application < Rails::Application
    config.api_only = true

    routes.append do
      get "/monkey/hello" => "monkey#hello"
      get "/monkey/error" => "monkey#error"
    end

    config.cache_classes = true
    config.eager_load = false
    config.active_support.deprecation = :stderr
    config.middleware.delete Rack::Lock
    config.middleware.delete ActionDispatch::Flash
    config.secret_token = "48837489qkuweoiuoqwehisuakshdjksadhaisdy78o34y138974xyqp9rmye8yrpiokeuioqwzyoiuxftoyqiuxrhm3iou1hrzmjk"
    config.secret_key_base = "2049671-96803948"
  end
end

class MonkeyController < ActionController::API
  def hello
    render :plain => {:Response => "Hello API!"}.to_json, content_type: 'application/json'
  end

  def error
    raise "Rails API fake error from controller"
  end
end

Rails50APIStack::Application.initialize!

Thread.new do
  Rack::Handler::Puma.run(Rails50APIStack::Application.to_app, {:Host => '127.0.0.1', :Port => 8150})
end


class Rails50Stack
  class Application < Rails::Application
    routes.append do
      get "/hello/world"       => "hello#world"
    end

    config.cache_classes = true
    config.eager_load = false
    config.active_support.deprecation = :stderr
    config.middleware.delete Rack::Lock
    config.middleware.delete ActionDispatch::Flash
    config.secret_token = "49837489qkuweoiuoqwehisuakshdjksadhaisdy78o34y138974xyqp9rmye8yrpiokeuioqwzyoiuxftoyqiuxrhm3iou1hrzmjk"
    config.secret_key_base = "2048671-96803948"
  end
end

class HelloController < ActionController::Base
  def world
    render :plain => "Hello world!"
  end
end

Rails50Stack::Application.initialize!

Thread.new do
  Rack::Handler::Puma.run(Rails50Stack::Application.to_app, {:Host => '127.0.0.1', :Port => 8140})
end

sleep(2)

# module Aaaa
#   def do(arg)
#     puts "#{arg} AAAA "
#     super
#   end
# end
#
# module Bbbb
#   include Aaaa
#
#   def do(arg)
#     puts "#{arg} BBBB "
#     super
#   end
# end
#
# class Cccc
#   prepend Aaaa
#
#   def do(arg)
#     puts "#{arg} CCCC "
#     # super
#   end
# end
#
# class Zzzz < Cccc
#   # prepend Aaaa
#   prepend Bbbb
#
#   def do(arg)
#     puts "#{arg} ZZZZ PI "
#     super
#   end
# end
#
# sleep 60
# puts Zzzz.ancestors
# Zzzz.new.do('hhhhmmmm? ')


