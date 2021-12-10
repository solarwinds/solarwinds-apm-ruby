# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'lograge'

describe "SimpleFormatter " do
  before(:all) do
    @in, out = IO.pipe
    @logger = ActiveSupport::Logger.new(out)
  end

  let (:msg) { @logger.warn "Message"; @in.gets }
  let (:exc_message) { @logger.warn StandardError.new ; @in.gets }

  load File.join(File.dirname(File.dirname(__FILE__)), 'instrumentation', 'logger_formatter_helper.rb')
end

describe "TaggedLogging " do
  before(:all) do
    @in, out = IO.pipe
    @logger = ActiveSupport::TaggedLogging.new(Logger.new(out))
  end

  let (:msg) { @logger.tagged('check', 'tag') { @logger.warn "Message" }; @in.gets }
  let (:exc_message) { @logger.warn StandardError.new ; @in.gets }

  load File.join(File.dirname(File.dirname(__FILE__)), 'instrumentation', 'logger_formatter_helper.rb')
end

describe "Lograge " do
  # lograge takes care of formatting controller logs, it isn't a logger per se
  # these tests check that the recommended config works
  # Lograge.custom_options = ->(_) { AppOpticsAPM::SDK.current_trace_info.hash_for_log }
  # and that no double traceIds are added

  let(:log_output) { StringIO.new }
  let(:logger) { Logger.new(log_output) }
  let(:subscriber) { Lograge::LogSubscribers::ActionController.new }
  let(:event_params) { { 'foo' => 'bar' } }
  let(:event) do
    ActiveSupport::Notifications::Event.new(
      'process_action.action_controller',
      Time.now,
      Time.now,
      2,
      status: 200,
      controller: 'MessageController',
      action: 'index',
      format: 'application/json',
      method: 'GET',
      path: '/home?foo=bar',
      params: event_params,
      db_runtime: 0.02,
      view_runtime: 0.01
    )
  end

  let (:msg) do
    subscriber.process_action(event)
    log_output.string
  end

  let (:exc_message) do
    skip # exceptions don't go through the lograge formatter
  end

  before do
    Lograge.logger = logger
    Lograge.formatter = Lograge::Formatters::KeyValue.new

    Lograge.custom_options = lambda do |_event|
      AppOpticsAPM::SDK.current_trace_info.hash_for_log
    end
  end

  load File.join(File.dirname(File.dirname(__FILE__)), 'instrumentation', 'logger_formatter_helper.rb')
end
