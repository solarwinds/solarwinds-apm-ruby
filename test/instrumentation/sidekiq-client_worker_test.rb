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

# https://github.com/mperham/sidekiq/blob/main/Changes.md#640
Sidekiq.strict_args!(false) if Sidekiq::VERSION >= '7.0.0'

# These tests also look at the continuation of context in the worker
# but without testing all the worker detail
class SidekiqClientTest < Minitest::Test
  def setup
    @collect_backtraces = SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces]
    @log_args = SolarWindsAPM::Config[:sidekiqclient][:log_args]
    @tracing_mode = SolarWindsAPM::Config[:tracing_mode]

    SolarWindsAPM::Config[:tracing_mode] = :enabled
    sleep 1 # there may be a bit of a lag somewhere with writing traces
    clear_all_traces
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
    assert_equal 10, refined_trace_count(traces), filter_traces(traces).pretty_inspect
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
    assert_equal 10, refined_trace_count(traces), filter_traces(traces).pretty_inspect
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
    assert_equal 10, refined_trace_count(traces), filter_traces(traces).pretty_inspect
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
    assert_equal 10, refined_trace_count(traces), filter_traces(traces).pretty_inspect
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
    assert_equal 10, refined_trace_count(traces), filter_traces(traces).pretty_inspect
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
    # We receive 6 trace events from the worker
    assert_equal 6, refined_trace_count(traces), filter_traces(traces).pretty_inspect
    assert same_trace_id?(traces), "more than one task_id found"
    validate_outer_layers(traces, 'sidekiq-worker')
  end


  def test_job_takes_an_obj
    # this is to test that we don't blow up things if w3c traceinfo can't be assigned

    ### TODO refute exception
    SolarWindsAPM::SDK.start_trace(:enqueue_test) do
      Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [Time.now], 'retry' => false)
    end
  end
end
