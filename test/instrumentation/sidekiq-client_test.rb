# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

if RUBY_VERSION >= '2.0'
  require 'minitest_helper'
  require 'sidekiq'
  require_relative "../jobs/remote_call_worker_job"
  require_relative "../jobs/db_worker_job"
  require_relative "../jobs/error_worker_job"

  class SidekiqClientTest < Minitest::Test
    def setup
      clear_all_traces
      @collect_backtraces = TraceView::Config[:sidekiq][:collect_backtraces]
      @log_args = TraceView::Config[:sidekiq][:log_args]
    end

    def teardown
      TraceView::Config[:sidekiq][:collect_backtraces] = @collect_backtraces
      TraceView::Config[:sidekiq][:log_args] = @log_args
    end

    def test_enqueue
      # Queue up a job to be run
      jid, xtrace = ::TraceView::API.start_trace(:enqueue_test) do
        Sidekiq::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 6, traces.count, "Trace count"
      validate_outer_layers(traces, 'enqueue_test')
      valid_edges?(traces)

      assert_equal 'sidekiq-client', traces[1]['Layer']
      assert_equal 'entry',          traces[1]['Label']
      assert_equal 'sidekiq-client', traces[2]['Layer']
      assert_equal 'exit',           traces[2]['Label']
    end

    def test_collect_backtraces_default_value
      assert_equal TV::Config[:sidekiq][:collect_backtraces], false, "default backtrace collection"
    end

    def test_log_args_default_value
      assert_equal TV::Config[:sidekiq][:log_args], true, "log_args default "
    end
  end
end
