# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

if RUBY_VERSION >= '1.9.3'
  require 'minitest_helper'
  require_relative "../jobs/resque/remote_call_worker_job"
  require_relative "../jobs/resque/error_worker_job"

  class ResqueClientTest < Minitest::Test
    def setup
      clear_all_traces
      @collect_backtraces = TraceView::Config[:resqueclient][:collect_backtraces]
      @log_args = TraceView::Config[:resqueclient][:log_args]
    end

    def teardown
      TraceView::Config[:resqueclient][:collect_backtraces] = @collect_backtraces
      TraceView::Config[:resqueclient][:log_args] = @log_args
    end

    def test_tv_methods_defined
      [ :enqueue, :enqueue_to, :dequeue ].each do |m|
        assert_equal true, ::Resque.method_defined?("#{m}_with_traceview")
      end

      assert_equal true, ::Resque::Worker.method_defined?("perform_with_traceview")
      assert_equal true, ::Resque::Job.method_defined?("fail_with_traceview")
    end

    def test_enqueue
      TraceView::API.start_trace('resque-client_test', '', {}) do
        Resque.enqueue(ResqueRemoteCallWorkerJob)
      end

      traces = get_all_traces

      assert_equal 6, traces.count, "trace count"
      validate_outer_layers(traces, 'resque-client_test')

      assert_equal "resque-client", traces[1]['Layer'], "entry event layer name"
      assert_equal "entry",         traces[1]['Label'], "entry event label"
      assert_equal "resque-client", traces[4]['Layer'], "exit event layer name"
      assert_equal "exit",         traces[4]['Label'], "exit event label"
    end

    def test_dequeue
      TraceView::API.start_trace('resque-client_test', '', {}) do
        Resque.dequeue(ResqueRemoteCallWorkerJob, { :generate => :moped })
      end

      traces = get_all_traces

      assert_equal 6, traces.count, "trace count"
      validate_outer_layers(traces, 'resque-client_test')

      assert_equal "resque-client", traces[1]['Layer'], "entry event layer name"
      assert_equal "entry",         traces[1]['Label'], "entry event label"
      assert_equal "resque-client", traces[4]['Layer'], "exit event layer name"
      assert_equal "exit",         traces[4]['Label'], "exit event label"
    end

    def test_legacy_resque_config
      skip
    end

    def test_collect_backtraces_default_value
      assert_equal TV::Config[:resqueclient][:collect_backtraces], false, "default backtrace collection"
    end

    def test_log_args_default_value
      assert_equal TV::Config[:resqueclient][:log_args], true, "log_args default "
    end

    def test_obey_collect_backtraces_when_false
      skip
      TraceView::Config[:resqueclient][:collect_backtraces] = false

      # Queue up a job to be run
      ::TraceView::API.start_trace(:enqueue_test) do
        resque::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
        Resque.enqueue(ResqueRemoteCallWorkerJob, [1, 2, 3])
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 23, traces.count, "Trace count"
      valid_edges?(traces)
      assert_equal 'resque-client',   traces[1]['Layer']
      assert_equal false,              traces[1].key?('Backtrace')
    end

    def test_obey_collect_backtraces_when_true
      skip
      TraceView::Config[:resqueclient][:collect_backtraces] = true

      # Queue up a job to be run
      ::TraceView::API.start_trace(:enqueue_test) do
        Resque.enqueue(ResqueRemoteCallWorkerJob, [1, 2, 3])
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 23, traces.count, "Trace count"
      valid_edges?(traces)
      assert_equal 'resque-client',   traces[1]['Layer']
      assert_equal true,               traces[1].key?('Backtrace')
    end

    def test_obey_log_args_when_false
      skip
      TraceView::Config[:resqueclient][:log_args] = false

      # Queue up a job to be run
      ::TraceView::API.start_trace(:enqueue_test) do
        Resque::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
      end

      # Allow the job to be run
      sleep 5

      traces = get_all_traces
      assert_equal 23, traces.count, "Trace count"
      valid_edges?(traces)
      assert_equal false, traces[1].key?('Args')
    end

    def test_obey_log_args_when_true
      skip
      TraceView::Config[:resqueclient][:log_args] = true

      # Queue up a job to be run
      ::TraceView::API.start_trace(:enqueue_test) do
        Resque::Client.push('queue' => 'critical', 'class' => ::RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)
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
