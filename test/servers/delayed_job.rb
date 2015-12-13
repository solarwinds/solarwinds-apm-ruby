# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require "rails"
require "delayed_job"

TraceView.logger.level = Logger::DEBUG

if ENV.key?('TRAVIS_PSQL_PASS')
  DJ_DB_URL = "postgres://postgres:#{ENV['TRAVIS_PSQL_PASS']}@127.0.0.1:5432/travis_ci_test"
else
  DJ_DB_URL = 'postgres://postgres@127.0.0.1:5432/travis_ci_test'
end

ActiveRecord::Base.establish_connection(DJ_DB_URL)

unless ActiveRecord::Base.connection.table_exists? :delayed_jobs
  TraceView.logger.info "[traceview/servers] Creating DelayedJob DB table."
  ActiveRecord::Migration.run(CreateDelayedJobs)
end

@worker_options = {
  :min_priority => ENV['MIN_PRIORITY'],
  :max_priority => ENV['MAX_PRIORITY'],
  :queues => (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','),
  :quiet => ENV['QUIET']
}

@worker_options[:sleep_delay] = ENV['SLEEP_DELAY'].to_i if ENV['SLEEP_DELAY']
@worker_options[:read_ahead] = ENV['READ_AHEAD'].to_i if ENV['READ_AHEAD']

TraceView.logger.info "[traceview/servers] Starting up background DelayedJob."

Thread.new do
  Delayed::Worker.new(@worker_options).start
end

# Allow it to boot
sleep 2
