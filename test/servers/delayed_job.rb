# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require "rails/all"
require "delayed_job"
require "action_controller/railtie" # require more if needed
require 'rack/handler/puma'
require File.expand_path(File.dirname(__FILE__) + '/../models/widget')

TraceView.logger.level = Logger::DEBUG
TraceView.logger.info "[traceview/info] Starting background utility rails app on localhost:8140."

if ENV.key?('TRAVIS_PSQL_PASS')
  DJ_DB_URL = "postgres://postgres:#{ENV['TRAVIS_PSQL_PASS']}@127.0.0.1:5432/travis_ci_test"
else
  DJ_DB_URL = 'postgres://postgres@127.0.0.1:5432/travis_ci_test'
end

ActiveRecord::Base.establish_connection(DJ_DB_URL)

unless ActiveRecord::Base.connection.table_exists? :delayed_jobs
  TraceView.logger.info "[traceview/servers] Creating DelayedJob DB table."
  require 'generators/delayed_job/templates/migration'
  ActiveRecord::Migration.run(CreateDelayedJobs)
end

unless ActiveRecord::Base.connection.table_exists? 'widgets'
  ActiveRecord::Migration.run(CreateWidgets)
end

class Rails40MetalStack < Rails::Application
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
end

Delayed::Job.delete_all

@worker_options = {
  :min_priority => ENV['MIN_PRIORITY'],
  :max_priority => ENV['MAX_PRIORITY'],
  :queues => (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','),
  :quiet => ENV['QUIET']
}

@worker_options[:sleep_delay] = ENV['SLEEP_DELAY'].to_i if ENV['SLEEP_DELAY']
@worker_options[:read_ahead] = ENV['READ_AHEAD'].to_i if ENV['READ_AHEAD']

TraceView.logger.info "[traceview/servers] Starting up background DelayedJob."

#Delayed::Worker.delay_jobs = false
Delayed::Worker.max_attempts = 0
Delayed::Worker.sleep_delay = 30

Thread.new do
  Delayed::Worker.new(@worker_options).start
end

# Allow it to boot
TraceView.logger.info "[traceview/servers] Waiting 5 seconds for DJ to boot..."
sleep 5
