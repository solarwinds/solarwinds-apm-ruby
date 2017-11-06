# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if RUBY_VERSION >= '2.0' && !defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'sidekiq'
  require_relative "../jobs/sidekiq/remote_call_worker_job"
  require_relative "../jobs/sidekiq/db_worker_job"
  require_relative "../jobs/sidekiq/error_worker_job"

  class SidekiqClientTest < Minitest::Test
    def setup
      clear_all_traces
      @collect_backtraces = AppOptics::Config[:sidekiqclient][:collect_backtraces]
      @log_args = AppOptics::Config[:sidekiqclient][:log_args]
    end

    def teardown
      AppOptics::Config[:sidekiqclient][:collect_backtraces] = @collect_backtraces
      AppOptics::Config[:sidekiqclient][:log_args] = @log_args
    end

    def refined_trace_count_check(traces)
      # we expect 23 traces, but it looks like there are cases where an extra 2 redis traces slip in
      # This method will allow the tests to pass despite the inconsistency in counts and also log some information
      
      redis_traces = traces.select { |h| h['Layer'] == 'redis' }
      if redis_traces.count == 4
        AppOptics.logger.debug("4 redis traces found: #{redis_traces}")
      else
        assert_equal 2, redis_traces.count
      end
      assert_equal 21, traces.count - redis_traces.count
    end

    def test_enqueue
      # Queue up a job to be run
      jid, _ = ::AppOptics::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      refined_trace_count_check(traces)
      assert valid_edges?(traces), "Invalid edge in traces"

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
      assert_equal AppOptics::Config[:sidekiqclient][:collect_backtraces], false, "default backtrace collection"
    end

    def test_log_args_default_value
      assert_equal AppOptics::Config[:sidekiqclient][:log_args], true, "log_args default "
    end

    def test_obey_collect_backtraces_when_false
      AppOptics::Config[:sidekiqclient][:collect_backtraces] = false

      # Queue up a job to be run
      ::AppOptics::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      refined_trace_count_check(traces)
      assert valid_edges?(traces), "Invalid edge in traces"
      assert_equal 'sidekiq-client',   traces[1]['Layer']
      assert_equal false,              traces[1].key?('Backtrace')
    end

    def test_obey_collect_backtraces_when_true
      AppOptics::Config[:sidekiqclient][:collect_backtraces] = true

      # Queue up a job to be run
      ::AppOptics::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      refined_trace_count_check(traces)
      assert valid_edges?(traces), "Invalid edge in traces"
      assert_equal 'sidekiq-client',   traces[1]['Layer']
      assert_equal true,               traces[1].key?('Backtrace')
    end

    def test_obey_log_args_when_false
      AppOptics::Config[:sidekiqclient][:log_args] = false

      # Queue up a job to be run
      ::AppOptics::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      refined_trace_count_check(traces)
      assert valid_edges?(traces), "Invalid edge in traces"
      assert_equal false, traces[1].key?('Args')
    end

    def test_obey_log_args_when_true
      AppOptics::Config[:sidekiqclient][:log_args] = true

      # Queue up a job to be run
      ::AppOptics::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      refined_trace_count_check(traces)
      assert valid_edges?(traces), "Invalid edge in traces"
      assert_equal true,         traces[1].key?('Args')
      assert_equal '[1, 2, 3]',  traces[1]['Args']
    end
  end
end
