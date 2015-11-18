# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'
require_relative "../jobs/delayed_job/remote_call_worker_job"
require_relative "../jobs/delayed_job/db_worker_job"
require_relative "../jobs/delayed_job/error_worker_job"

class DelayedJobWorkerTest < Minitest::Test
  def setup
    clear_all_traces
    @collect_backtraces = TraceView::Config[:delayed_jobworker][:collect_backtraces]
    @log_args = TraceView::Config[:delayed_jobworker][:log_args]
  end

  def teardown
    TraceView::Config[:delayed_jobworker][:collect_backtraces] = @collect_backtraces
    TraceView::Config[:delayed_jobworker][:log_args] = @log_args
  end

  def test_reports_version_init
    init_kvs = ::TraceView::Util.build_init_report
    assert init_kvs.key?('Ruby.DJ.Version')
    assert_equal "DJ-#{::Delayed::VERSION}", init_kvs['Ruby.DJ.Version']
  end

  def test_job_run
  end

  def test_jobs_with_errors
  end

  def test_collect_backtraces_default_value
    assert_equal TV::Config[:delayed_jobworker][:collect_backtraces], false, "default backtrace collection"
  end

  def test_log_args_default_value
    assert_equal TV::Config[:delayed_jobworker][:log_args], true, "log_args default "
  end

  def test_obey_collect_backtraces_when_false
    TraceView::Config[:delayed_jobworker][:collect_backtraces] = false
  end

  def test_obey_collect_backtraces_when_true
    # FIXME: This can't be tested with the current Sidekiq minitest integration (e.g. already booted
    # sidekiq in a different process)
    skip

    TraceView::Config[:delayed_jobworker][:collect_backtraces] = true

  end

  def test_obey_log_args_when_false
    # FIXME: This can't be tested with the current Sidekiq minitest integration (e.g. already booted
    # sidekiq in a different process)
    skip

  end

  def test_obey_log_args_when_true
    TraceView::Config[:delayed_jobworker][:log_args] = true

    # Queue up a job to be run
  end
end
