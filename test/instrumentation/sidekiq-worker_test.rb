# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'
require 'sidekiq'
require_relative "../jobs/remote_call_worker_job"
require_relative "../jobs/db_worker_job"
require_relative "../jobs/error_worker_job"

class SidekiqWorkerTest < Minitest::Test
  def setup
    clear_all_traces
    @collect_backtraces = TraceView::Config[:sidekiq][:collect_backtraces]
    @log_args = TraceView::Config[:sidekiq][:log_args]
  end

  def teardown
    TraceView::Config[:sidekiq][:collect_backtraces] = @collect_backtraces
    TraceView::Config[:sidekiq][:log_args] = @log_args
  end

  def test_reports_version_init
    init_kvs = ::TraceView::Util.build_init_report
    assert init_kvs.key?('Ruby.Sidekiq.Version')
    assert_equal init_kvs['Ruby.Sidekiq.Version'], "Sidekiq-#{::Sidekiq::VERSION}"
  end

  def test_job_run
    # Queue up a job to be run
    Sidekiq::Client.push('queue' => 'critical', 'class' => RemoteCallWorkerJob, 'args' => [1, 2, 3], 'retry' => false)

    # Allow the job to be run
    sleep 5

    traces = get_all_traces
    require 'pry-byebug'; binding.pry
    assert_equal 19, traces.count, "Trace count"
    validate_outer_layers(traces, "sidekiq-worker")
    valid_edges?(traces)

    assert_equal "sidekiq-worker", traces[0]['Layer']
    assert_equal "entry", traces[0]['Label']
    assert_equal "perform", traces[0]['Op']
    assert_equal traces[0].key?('HTTP-Host'), true
    assert_equal "Worker", traces[0]['Method']
    assert_equal "[1, 2, 3]", traces[0]['Args']
    assert_equal "Sidekiq_critical", traces[0]['Controller']
    assert_equal "RemoteCallWorkerJob", traces[0]['Action']
    assert_equal "/sidekiq/critical/RemoteCallWorkerJob", traces[0]['URL']
    assert_equal "critical", traces[0]['Queue']

    assert_equal traces[0].key?('Backtrace'), false
    assert_equal traces[4]['Layer'], "excon"
    assert_equal traces[4]['Label'], "entry"
    assert_equal traces[17]['Layer'], "memcache"
  end

  def test_jobs_with_errors
    # Queue up a job to be run
    Sidekiq::Client.push('queue' => 'critical', 'class' => ErrorWorkerJob, 'args' => [1, 2, 3], 'retry' => false)

    # Allow the job to be run
    sleep 5

    traces = get_all_traces
    assert_equal 3, traces.count, "Trace count"
    validate_outer_layers(traces, "sidekiq-worker")
    valid_edges?(traces)

    assert_equal traces[1]['Layer'], 'sidekiq-worker'
    assert_equal traces[1]['Label'], 'error'
    assert_equal traces[1]['ErrorClass'], "RuntimeError"
    assert traces[1].key?('ErrorMsg')
    assert traces[1].key?('Backtrace')
  end

  def test_collect_backtraces_default_value
    assert_equal TV::Config[:sidekiq][:collect_backtraces], false, "default backtrace collection"
  end
end
