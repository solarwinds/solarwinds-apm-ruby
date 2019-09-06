##
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

#  This is a Rails API stack that launches on a background
#  thread and listens on port 8150.
#
if ENV['DBTYPE'] == 'mysql2'
  AppOpticsAPM::Test.set_mysql2_env
elsif ENV['DBTYPE'] =~ /postgres/
  AppOpticsAPM::Test.set_postgresql_env
else
  AppOpticsAPM.logger.warn "[appoptics_apm/rails] Unidentified DBTYPE: #{ENV['DBTYPE']}"
  AppOpticsAPM.logger.debug "[appoptics_apm/rails] Defaulting to postgres DB for background Rails server."
  AppOpticsAPM::Test.set_postgresql_env
end

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
require File.expand_path(File.dirname(__FILE__) + '/../models/widget')

AppOpticsAPM.logger.info "[appoptics_apm/info] Starting background utility rails app on localhost:8150."

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

    config.cache_classes = true
    config.eager_load = false
    config.active_support.deprecation = :stderr
    config.middleware.delete Rack::Lock
    config.middleware.delete ActionDispatch::Flash
    config.secret_token = "48837489qkuweoiuoqwehisuakshdjksadhaisdy78o34y138974xyqp9rmye8yrpiokeuioqwzyoiuxftoyqiuxrhm3iou1hrzmjk"
    config.secret_key_base = "2049671-96803948"
    config.sqlite3 = {} # deal with https://github.com/rails/rails/issues/37048
  end
end

#################################################
#  Controllers
#################################################

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

sleep(2)
