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
#

# Set the database.  Default is postgresql.
if ENV['DBTYPE'] == 'mysql2'
  TraceView::Test.set_mysql2_env
elsif ENV['DBTYPE'] == 'postgresql'
  TraceView::Test.set_postgresql_env
else
  TV.logger.warn "Unidentified DBTYPE: #{ENV['DBTYPE']}" unless ENV['DBTYPE'] == "postgresql"
  TV.logger.debug "Defaulting to postgres DB for background Rails server."
  TraceView::Test.set_postgresql_env
end

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
require "rails/test_unit/railtie"

require 'rack/handler/puma'
require File.expand_path(File.dirname(__FILE__) + '/../models/widget')

TraceView.logger.info "[traceview/info] Starting background utility rails app on localhost:8150."

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

unless ActiveRecord::Base.connection.table_exists? 'widgets'
  ActiveRecord::Migration.run(CreateWidgets)
end

module Rails50APIStack
  class Application < Rails::Application
    config.api_only = true

    routes.append do
      get "/monkey/hello" => "monkey#hello"
      get "/monkey/error" => "monkey#error"
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
    config.middleware.delete Rack::Lock
    config.middleware.delete ActionDispatch::Flash

    # We need a secret token for session, cookies, etc.
    config.secret_token = "48837489qkuweoiuoqwehisuakshdjksadhaisdy78o34y138974xyqp9rmye8yrpiokeuioqwzyoiuxftoyqiuxrhm3iou1hrzmjk"
    config.secret_key_base = "2049671-96803948"
  end
end

#################################################
#  Controllers
#################################################

class MonkeyController < ActionController::API
  def hello
    #render :json => { :Response => "Hello API!"}.to_json
    # Work around for Rails beta issue with rendering json
    render :plain => { :Response => "Hello API!"}.to_json, content_type: 'application/json'
  end

  def error
    raise "Rails API fake error from controller"
  end
end

Rails50APIStack::Application.initialize!

Thread.new do
  Rack::Handler::Puma.run(Rails50APIStack::Application.to_app, {:Host => '127.0.0.1', :Port => 8150})
end

sleep(2)
