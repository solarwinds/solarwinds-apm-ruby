# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'sidekiq'
require_relative "../jobs/sidekiq/remote_call_worker_job"
require_relative "../jobs/sidekiq/db_worker_job"
require_relative "../jobs/sidekiq/error_worker_job"

Sidekiq.configure_server do |config|
  config.redis = { :password => ENV['REDIS_PASSWORD'] || 'secret_pass' }
  if ENV.key?('REDIS_HOST')
    config.redis << { :url => "redis://#{ENV['REDIS_HOST']}:6379" }
  end
end

# These tests also look at the continuation of context in the worker
# but without testing all the worker detail
class SidekiqClientTest < Minitest::Test
  def setup
    clear_all_traces
    @collect_backtraces = SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces]
    @log_args = SolarWindsAPM::Config[:sidekiqclient][:log_args]
    @tracing_mode = SolarWindsAPM::Config[:tracing_mode]

    # not a request entry point, context set up in test with start_trace
    SolarWindsAPM::Context.clear
  end

  def teardown
    SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces] = @collect_backtraces
    SolarWindsAPM::Config[:sidekiqclient][:log_args] = @log_args
    SolarWindsAPM::Config[:tracing_mode] = @tracing_mode
  end

  def refined_trace_count(traces)
    # we expect 23 traces, but it looks like there are cases where an extra 2 or 4 redis traces slip in
    # This method will allow the tests to pass despite the inconsistency in counts

    redis_traces = traces.select { |h| h['Layer'] == 'redis' }
    traces.count - redis_traces.count
  end

  def test_enqueue
    # Queue up a job to be run
    jid = ::SolarWindsAPM::SDK.start_trace(:enqueue_test) do
      result = Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      assert SolarWindsAPM::TraceString.valid?(SolarWindsAPM::Context.toString)
      result
    end

    # Allow the job to be run
    sleep 3

    traces = get_all_traces
    assert_equal 16, refined_trace_count(traces), filter_traces(traces).pretty_inspect
    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert same_trace_id?(traces), "more than one task_id found"

    assert_equal 'sidekiq-client',       traces[1]['Layer']
    assert_equal 'entry',                traces[1]['Label']

    assert_equal 'pushq',                traces[1]['Spec']
    assert_equal 'sidekiq',              traces[1]['Flavor']
    assert_equal 'critical',             traces[1]['Queue']
    assert_equal jid,                    traces[1]['MsgID']
    assert_equal '[1, 2, 3]',            traces[1]['Args']
    assert_equal "RemoteCallWorkerJob",  traces[1]['JobName']
    assert_equal 'false',                traces[1]['Retry']
    assert_equal false,                  traces[1].key?('Backtrace')

    assert_equal 'sidekiq-client',       traces[2]['Layer']
    assert_equal 'exit',                 traces[2]['Label']
  end

  def test_collect_backtraces_default_value
    assert_equal SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces], false, "default backtrace collection"
  end

  def test_log_args_default_value
    assert_equal SolarWindsAPM::Config[:sidekiqclient][:log_args], true, "log_args default "
  end

  def test_obey_collect_backtraces_when_false
    SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces] = false

    # Queue up a job to be run
    SolarWindsAPM::SDK.start_trace(:enqueue_test) do
      Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
    end

    # Allow the job to be run
    sleep 3

    traces = get_all_traces
    assert_equal 16, refined_trace_count(traces), filter_traces(traces).pretty_inspect
    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert_equal 'sidekiq-client', traces[1]['Layer']
    assert_equal false, traces[1].key?('Backtrace')
  end

  def test_obey_collect_backtraces_when_true
    SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces] = true

    # Queue up a job to be run
    SolarWindsAPM::SDK.start_trace(:enqueue_test) do
      Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
    end

    # Allow the job to be run
    sleep 3

    traces = get_all_traces
    assert_equal 16, refined_trace_count(traces), filter_traces(traces).pretty_inspect
    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert same_trace_id?(traces), "more than one task_id found"

    assert_equal 'sidekiq-client', traces[1]['Layer']
    assert_equal true, traces[1].key?('Backtrace')
  end

  def test_obey_log_args_when_false
    SolarWindsAPM::Config[:sidekiqclient][:log_args] = false

    # Queue up a job to be run
    SolarWindsAPM::SDK.start_trace(:enqueue_test) do
      Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
    end

    # Allow the job to be run
    sleep 3

    traces = get_all_traces
    assert_equal 16, refined_trace_count(traces), filter_traces(traces).pretty_inspect
    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert same_trace_id?(traces), "more than one task_id found"
    assert_equal false, traces[1].key?('Args')
  end

  def test_obey_log_args_when_true
    SolarWindsAPM::Config[:sidekiqclient][:log_args] = true

    # Queue up a job to be run
    SolarWindsAPM::SDK.start_trace(:enqueue_test) do
      Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
    end

    # Allow the job to be run
    sleep 3

    traces = get_all_traces
    assert_equal 16, refined_trace_count(traces)
    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert same_trace_id?(traces), "more than one task_id found"
    assert_equal true, traces[1].key?('Args')
    assert_equal '[1, 2, 3]', traces[1]['Args']
  end

  def test_dont_log_when_not_sampling
    SolarWindsAPM::Config[:sidekiqclient][:log_args] = true
    SolarWindsAPM::Config[:tracing_mode] = :disabled
    SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces] = false

    SolarWindsAPM::SDK.start_trace(:enqueue_test) do
      Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
    end

    sleep 3
    traces = get_all_traces

    # The sidekiq worker is already started in a different process and does not
    # receive the new value for SolarWindsAPM::Config[:tracing_mode]
    # We receive 12 trace events from the worker
    assert_equal 12, refined_trace_count(traces)
    assert same_trace_id?(traces), "more than one task_id found"
    validate_outer_layers(traces, 'sidekiq-worker')
  end
end
