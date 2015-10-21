# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

if RUBY_VERSION >= '2.0' && !defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'sidekiq'
  require_relative "../jobs/remote_call_worker_job"
  require_relative "../jobs/db_worker_job"
  require_relative "../jobs/error_worker_job"

  class SidekiqClientTest < Minitest::Test
    def setup
      clear_all_traces
      @collect_backtraces = TraceView::Config[:sidekiqclient][:collect_backtraces]
      @log_args = TraceView::Config[:sidekiqclient][:log_args]
    end

    def teardown
      TraceView::Config[:sidekiqclient][:collect_backtraces] = @collect_backtraces
      TraceView::Config[:sidekiqclient][:log_args] = @log_args
    end

    def test_enqueue
      # Queue up a job to be run
      jid, _ = ::TraceView::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 23, traces.count, "Trace count"
      valid_edges?(traces)

      assert_equal 'sidekiq-client',       traces[1]['Layer']
      assert_equal 'entry',                traces[1]['Label']

      assert_equal 'msgclient',            traces[1]['Spec']
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
      assert_equal TV::Config[:sidekiqclient][:collect_backtraces], false, "default backtrace collection"
    end

    def test_log_args_default_value
      assert_equal TV::Config[:sidekiqclient][:log_args], true, "log_args default "
    end

    def test_obey_collect_backtraces_when_false
      TraceView::Config[:sidekiqclient][:collect_backtraces] = false

      # Queue up a job to be run
      ::TraceView::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 23, traces.count, "Trace count"
      valid_edges?(traces)
      assert_equal 'sidekiq-client',   traces[1]['Layer']
      assert_equal false,              traces[1].key?('Backtrace')
    end

    def test_obey_collect_backtraces_when_true
      TraceView::Config[:sidekiqclient][:collect_backtraces] = true

      # Queue up a job to be run
      ::TraceView::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 23, traces.count, "Trace count"
      valid_edges?(traces)
      assert_equal 'sidekiq-client',   traces[1]['Layer']
      assert_equal true,               traces[1].key?('Backtrace')
    end

    def test_obey_log_args_when_false
      TraceView::Config[:sidekiqclient][:log_args] = false

      # Queue up a job to be run
      ::TraceView::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 23, traces.count, "Trace count"
      valid_edges?(traces)
      assert_equal false, traces[1].key?('Args')
    end

    def test_obey_log_args_when_true
      TraceView::Config[:sidekiqclient][:log_args] = true

      # Queue up a job to be run
      ::TraceView::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 23, traces.count, "Trace count"
      valid_edges?(traces)
      assert_equal true,         traces[1].key?('Args')
      assert_equal '[1, 2, 3]',  traces[1]['Args']
    end
  end
end
