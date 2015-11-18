# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

TraceView.logger.info "[traceview/servers] Starting up background DelayedJob."

@worker_options = {
  :min_priority => ENV['MIN_PRIORITY'],
  :max_priority => ENV['MAX_PRIORITY'],
  :queues => (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','),
  :quiet => ENV['QUIET']
}

@worker_options[:sleep_delay] = ENV['SLEEP_DELAY'].to_i if ENV['SLEEP_DELAY']
@worker_options[:read_ahead] = ENV['READ_AHEAD'].to_i if ENV['READ_AHEAD']

Thread.new do
  Delayed::Worker.new(@worker_options).start
end

# Allow it to boot
sleep 2
