# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This is a Rails app that launches a DelayedJob worker
# in a background thread.
#
require "rails/all"
require "delayed_job"
require "action_controller/railtie"
require 'rack/handler/puma'
require 'solarwinds_apm/test'

require File.expand_path(File.dirname(__FILE__) + '/../models/widget')

# SolarWindsAPM.logger.level = Logger::DEBUG
SolarWindsAPM.logger.info "[solarwinds_apm/info] Starting background utility rails app on localhost:8140."

SolarWindsAPM::Test.set_postgresql_env

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

unless ActiveRecord::Base.connection.table_exists? :delayed_jobs
  SolarWindsAPM.logger.info "[solarwinds_apm/servers] Creating DelayedJob DB table."

  dj_dir = Gem::Specification.find_by_name('delayed_job_active_record').gem_dir
  template = File.open(File.join(dj_dir, "lib/generators/delayed_job/templates/migration.rb"))

  migration_context = Class.new do
    def get_binding
      binding
    end

    private

    def migration_version
      if ActiveRecord::VERSION::MAJOR >= 5
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
  migration_ruby = ERB.new(template.read).result(migration_context.new.get_binding)
  eval migration_ruby

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

  config.cache_classes = true
  config.eager_load = false
  config.active_support.deprecation = :stderr
  config.middleware.delete "Rack::Lock"
  config.middleware.delete "ActionDispatch::Flash"
  config.middleware.delete "ActionDispatch::BestStandardsSupport"
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

SolarWindsAPM.logger.info "[solarwinds_apm/servers] Starting up background DelayedJob."

#Delayed::Worker.delay_jobs = false
Delayed::Worker.max_attempts = 1
Delayed::Worker.sleep_delay = 10

Thread.new do
  Delayed::Worker.new(@worker_options).start
end

# Allow it to boot
SolarWindsAPM.logger.info "[solarwinds_apm/servers] Waiting 5 seconds for DJ to boot..."
sleep 5
