# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

if (File.basename(ENV['BUNDLE_GEMFILE']) =~ /rails/) == 0
  require 'minitest_helper'
  require_relative "../jobs/delayed_job/remote_call_worker_job"
  require_relative "../jobs/delayed_job/db_worker_job"
  require_relative "../jobs/delayed_job/error_worker_job"
  require_relative '../models/widget'

  # Delete all pre-existing jobs before we start
  Delayed::Job.delete_all

  class DelayedJobClientTest < Minitest::Test
    def setup
      clear_all_traces
      @collect_backtraces = TraceView::Config[:delayed_jobclient][:collect_backtraces]
      @log_args = TraceView::Config[:delayed_jobclient][:log_args]
    end

    def teardown
      TraceView::Config[:delayed_jobclient][:collect_backtraces] = @collect_backtraces
      TraceView::Config[:delayed_jobclient][:log_args] = @log_args
    end

    def test_delay
      w = Widget.new(:name => 'blah', :description => 'This is a wonderful widget.')
      w.save

      TV::API.start_trace('dj_delay') do
        w.delay.do_work(1, 2, 3)
      end

      sleep 5

      traces = get_all_traces
      assert_equal 10, traces.count, "Trace count"
      valid_edges?(traces)

      assert_equal 'dj_delay',              traces[0]['Layer']
      assert_equal 'entry',                 traces[0]['Label']
      assert_equal 'delayed_job-client',    traces[1]['Layer']
      assert_equal 'entry',                 traces[1]['Label']
      assert_equal 'pushq',                 traces[1]['Spec']
      assert_equal 'DelayedJob',            traces[1]['Flavor']
      assert_equal 'Widget#do_work',        traces[1]['JobName']
      assert_equal 'activerecord',          traces[2]['Layer']
      assert_equal 'entry',                 traces[2]['Label']
      assert_equal 'activerecord',          traces[3]['Layer']
      assert_equal 'exit',                  traces[3]['Label']
      assert_equal 'delayed_job-client',    traces[4]['Layer']
      assert_equal 'exit',                  traces[4]['Label']
      assert_equal 'dj_delay',              traces[5]['Layer']
      assert_equal 'exit',                  traces[5]['Label']

    end

    def test_collect_backtraces_default_value
      assert_equal TV::Config[:delayed_jobclient][:collect_backtraces], false, "default backtrace collection"
    end

    def test_log_args_default_value
      assert_equal TV::Config[:delayed_jobclient][:log_args], true, "log_args default "
    end

    def test_obey_collect_backtraces_when_false
      TraceView::Config[:delayed_jobclient][:collect_backtraces] = false

      w = Widget.new(:name => 'blah', :description => 'This is a wonderful widget.')
      w.save

      TV::API.start_trace('dj_delay') do
        w.delay.do_work(1, 2, 3)
      end

      sleep 5

      traces = get_all_traces
      assert_equal 10, traces.count, "Trace count"
      valid_edges?(traces)

      assert_equal 'delayed_job-client',    traces[1]['Layer']
      assert_equal 'entry',                 traces[1]['Label']
      assert_equal false,                   traces[1].key?('Backtrace')
    end

    def test_obey_collect_backtraces_when_true
      TraceView::Config[:delayed_jobclient][:collect_backtraces] = true

      w = Widget.new(:name => 'blah', :description => 'This is a wonderful widget.')
      w.save

      TV::API.start_trace('dj_delay') do
        w.delay.do_work(1, 2, 3)
      end

      sleep 5

      traces = get_all_traces
      assert_equal 10, traces.count, "Trace count"
      valid_edges?(traces)

      assert_equal 'delayed_job-client',    traces[1]['Layer']
      assert_equal 'entry',                 traces[1]['Label']
      assert_equal true,                   traces[1].key?('Backtrace')
    end
  end
end
