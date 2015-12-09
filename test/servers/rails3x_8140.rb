# Taken from: https://www.amberbit.com/blog/2014/2/14/putting-ruby-on-rails-on-a-diet/
# Port of https://gist.github.com/josevalim/1942658 to Rails 4
# Original author: Jose Valim
# Updated by: Peter Giacomo Lombardo
#
# Run this file with:
#
#   bundle exec RAILS_ENV=production rackup -p 3000 -s thin
#
# And access:
#
#   http://localhost:3000/hello/world
#
# The following lines should come as no surprise. Except by
# ActionController::Metal, it follows the same structure of
# config/application.rb, config/environment.rb and config.ru
# existing in any Rails 4 app. Here they are simply in one
# file and without the comments.
require "rails"
require "action_controller/railtie" # require more if needed
require 'rack/handler/puma'
require_relative '../models/widget'

TraceView.logger.info "[traceview/info] Starting background utility rails app on localhost:8140."

if ENV.key?('TRAVIS_PSQL_PASS')
  ENV['DATABASE_URL'] = "postgresql://postgres:#{ENV['TRAVIS_PSQL_PASS']}@127.0.0.1:5432/travis_ci_test"
else
  ENV['DATABASE_URL'] = 'postgresql://postgres@127.0.0.1:5432/travis_ci_test'
end

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

unless ActiveRecord::Base.connection.table_exists? 'widgets'
  CreateWidgets.migrate(:up)
end

class Rails32MetalStack < Rails::Application
  routes.append do
    get "/hello/world" => "hello#world"
    get "/hello/metal" => "ferro#world"
  end

  # Enable cache classes. Production style.
  config.cache_classes = true
  config.eager_load = false

  # uncomment below to display errors
  # config.consider_all_requests_local = true

  config.active_support.deprecation = :stderr

  # Here you could remove some middlewares, for example
  # Rack::Lock, ActionDispatch::Flash and  ActionDispatch::BestStandardsSupport below.
  # The remaining stack is printed on rackup (for fun!).
  # Rails API has config.middleware.api_only! to get
  # rid of browser related middleware.
  config.middleware.delete "Rack::Lock"
  config.middleware.delete "ActionDispatch::Flash"
  config.middleware.delete "ActionDispatch::BestStandardsSupport"

  # We need a secret token for session, cookies, etc.
  config.secret_token = "49837489qkuweoiuoqwehisuakshdjksadhaisdy78o34y138974xyqp9rmye8yrpiokeuioqwzyoiuxftoyqiuxrhm3iou1hrzmjk"
  config.secret_key_base = "2048671-96803948"
end

#################################################
#  Controllers
#################################################

class HelloController < ActionController::Base
  def world
    render :text => "Hello world!"
  end
end

class FerroController < ActionController::Metal
  include AbstractController::Rendering

  def world
    render :text => "Hello world!"
  end

  include TraceViewMethodProfiling
  profile_method :world, 'world'
end

Rails32MetalStack.initialize!

Thread.new do
  Rack::Handler::Puma.run(Rails32MetalStack.to_app, {:Host => '127.0.0.1', :Port => 8140})
end

sleep(2)
