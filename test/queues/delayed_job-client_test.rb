# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

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
    @collect_backtraces = SolarWindsAPM::Config[:delayed_jobclient][:collect_backtraces]
    # @log_args = SolarWindsAPM::Config[:delayed_jobclient][:log_args] # there is no code using SolarWindsAPM::Config[:delayed_jobclient][:log_args]
  end

  def teardown
    SolarWindsAPM::Config[:delayed_jobclient][:collect_backtraces] = @collect_backtraces
    # SolarWindsAPM::Config[:delayed_jobclient][:log_args] = @log_args # there is no code using SolarWindsAPM::Config[:delayed_jobclient][:log_args]
  end

  def test_delay
    w = Widget.new(:name => 'blah', :description => 'This is a wonderful widget.')
    w.save

    SolarWindsAPM::SDK.start_trace('dj_delay') do
      w.delay.do_work(1, 2, 3)
    end

    sleep 15

    traces = get_all_traces
    assert valid_edges?(traces, false), "Invalid edge in traces" # we don't connect traces from clients and workers

    assert_equal 'dj_delay',              traces[0]['Layer']
    assert_equal 'entry',                 traces[0]['Label']
    assert_equal 'delayed_job-client',    traces[1]['Layer']
    assert_equal 'entry',                 traces[1]['Label']
    assert_equal 'pushq',                 traces[1]['Spec']
    assert_equal 'DelayedJob',            traces[1]['Flavor']
    assert_equal 'Widget#do_work',        traces[1]['JobName']
    assert_equal 'delayed_job-client',    traces[2]['Layer']
    assert_equal 'exit',                  traces[2]['Label']
    assert_equal 'dj_delay',              traces[3]['Layer']
    assert_equal 'exit',                  traces[3]['Label']

  end

  def test_collect_backtraces_default_value
    assert_equal SolarWindsAPM::Config[:delayed_jobclient][:collect_backtraces], false, "default backtrace collection"
  end

  def test_log_args_default_value
    skip # TODO: there is no code checking SolarWindsAPM::Config[:delayed_jobclient][:log_args]
    assert_equal true, SolarWindsAPM::Config[:delayed_jobclient][:log_args], "test log_args on by default "
  end

  def test_obey_collect_backtraces_when_false
    SolarWindsAPM::Config[:delayed_jobclient][:collect_backtraces] = false

    w = Widget.new(:name => 'blah', :description => 'This is a wonderful widget.')
    w.save

    SolarWindsAPM::SDK.start_trace('dj_delay') do
      w.delay.do_work(1, 2, 3)
    end

    traces = get_all_traces
    assert valid_edges?(traces, false), "Invalid edge in traces" # we don't connect traces from clients and workers

    assert_equal 'delayed_job-client',    traces[1]['Layer']
    assert_equal 'entry',                 traces[1]['Label']
    assert_equal false,                   traces[1].key?('Backtrace')
  end

  def test_obey_collect_backtraces_when_true
    SolarWindsAPM::Config[:delayed_jobclient][:collect_backtraces] = true

    w = Widget.new(:name => 'blah', :description => 'This is a wonderful widget.')
    w.save

    SolarWindsAPM::SDK.start_trace('dj_delay') do
      w.delay.do_work(1, 2, 3)
    end

    traces = get_all_traces
    assert valid_edges?(traces, false), "Invalid edge in traces" # we don't connect traces from clients and workers

    assert_equal 'delayed_job-client',    traces[1]['Layer']
    assert_equal 'entry',                 traces[1]['Label']
    assert_equal true,                   traces[1].key?('Backtrace')
  end
end
