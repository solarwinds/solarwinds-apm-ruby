# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require_relative "../jobs/resque/remote_call_worker_job"
require_relative "../jobs/resque/error_worker_job"

Resque.redis = Redis.new(:host => ENV['REDIS_HOST'] || ENV['REDIS_SERVER'] || '127.0.0.1',
                         :password => ENV['REDIS_PASSWORD'] || 'secret_pass')

Resque.enqueue(ResqueRemoteCallWorkerJob) # calling this here once to avoid other calls having an auth span

describe 'ResqueClient' do
  before do

    @tm = SolarWindsAPM::Config[:tracing_mode]
    @collect_backtraces = SolarWindsAPM::Config[:resqueclient][:collect_backtraces]
    @log_args = SolarWindsAPM::Config[:resqueclient][:log_args]

    SolarWindsAPM::Config[:tracing_mode] = :enabled

    # TODO remove with NH-11132
    # not a request entry point, context set up in test with start_trace
    work_off_jobs
    SolarWindsAPM::Context.clear
    clear_all_traces
  end

  after do
    SolarWindsAPM::Config[:resqueclient][:collect_backtraces] = @collect_backtraces
    SolarWindsAPM::Config[:resqueclient][:log_args] = @log_args
    SolarWindsAPM::Config[:tracing_mode] = @tm
    Resque.redis.flushall
  end

  it 'Solarwinds classes prepended' do
    Resque.ancestors[0] = SolarWindsAPM::Inst::Resque::Dequeue
    Resque::Job.ancestors[0] = SolarWindsAPM::Inst::ResqueJob
  end

  # TODO what is this?
  def not_tracing_validation
    assert Resque.enqueue(ResqueRemoteCallWorkerJob), "not tracing; enqueue return value"
    assert Resque.enqueue(ResqueRemoteCallWorkerJob, 1, 2, "3"), "not tracing; enqueue extra params"
  end

  it 'enqueue' do
    SolarWindsAPM::SDK.start_trace('resque-client_test') do
      Resque.enqueue(ResqueRemoteCallWorkerJob)
    end
    work_off_jobs

    traces = get_all_traces

    assert_equal 12, traces.count, filter_traces(traces).pretty_inspect
    assert same_trace_id?(traces), filter_traces(traces).pretty_inspect

    assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
    assert_equal "entry",                      traces[1]['Label'], "entry event label"
    assert_equal "pushq",                      traces[1]['Spec']
    assert_equal "resque",                     traces[1]['Flavor']
    assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
    assert_equal "critical",                   traces[1]['Queue']
    assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
    assert_equal "exit",                       traces[4]['Label'], "exit event label"

    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-client" }.size, "client layers missing \n#{filter_traces(traces).pretty_inspect}"
    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-worker" }.size, "worker layers missing \n#{filter_traces(traces).pretty_inspect}"
  end

  it 'dequeue' do
    SolarWindsAPM::SDK.start_trace('resque-client_test') do
      Resque.dequeue(ResqueRemoteCallWorkerJob, { :generate => :moped })
    end
    work_off_jobs

    traces = get_all_traces

    assert_equal 6, traces.count, filter_traces(traces).pretty_inspect
    assert same_trace_id?(traces), filter_traces(traces).pretty_inspect

    assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
    assert_equal "entry",                      traces[1]['Label'], "entry event label"
    assert_equal "pushq",                      traces[1]['Spec']
    assert_equal "resque",                     traces[1]['Flavor']
    assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
    assert_equal "critical",                   traces[1]['Queue']
    assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
    assert_equal "exit",                        traces[4]['Label'], "exit event label"

    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-client" }.size, "client layers missing \n#{filter_traces(traces).pretty_inspect}"
  end

  it 'collect_backtraces_default_value' do
    assert_equal SolarWindsAPM::Config[:resqueclient][:collect_backtraces], true, "default backtrace collection"
  end

  it 'log_args_default_value' do
    assert_equal SolarWindsAPM::Config[:resqueclient][:log_args], true, "log_args default "
  end

  it 'obey_collect_backtraces_when_false' do
    SolarWindsAPM::Config[:resqueclient][:collect_backtraces] = false

    # Queue up a job to be run
    SolarWindsAPM::SDK.start_trace('resque-client_test') do
      Resque.enqueue(ResqueRemoteCallWorkerJob, [1, 2, 3])
    end
    work_off_jobs

    traces = get_all_traces

    assert_equal 12, traces.count, filter_traces(traces).pretty_inspect
    assert same_trace_id?(traces), filter_traces(traces).pretty_inspect

    assert_equal false, traces[1].key?('Backtrace')

    assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
    assert_equal "entry",                      traces[1]['Label'], "entry event label"
    assert_equal "pushq",                      traces[1]['Spec']
    assert_equal "resque",                     traces[1]['Flavor']
    assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
    assert_equal "critical",                   traces[1]['Queue']
    assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
    assert_equal "exit",                       traces[4]['Label'], "exit event label"

    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-client" }.size, "client layers missing \n#{filter_traces(traces).pretty_inspect}"
    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-worker" }.size, "worker layers missing \n#{filter_traces(traces).pretty_inspect}"
  end

  it 'obey_collect_backtraces_when_true' do
    SolarWindsAPM::Config[:resqueclient][:collect_backtraces] = true

    # Queue up a job to be run
    SolarWindsAPM::SDK.start_trace('resque-client_test') do
      Resque.enqueue(ResqueRemoteCallWorkerJob, [1, 2, 3])
    end
    work_off_jobs

    traces = get_all_traces

    assert_equal 12, traces.count, filter_traces(traces).pretty_inspect
    assert same_trace_id?(traces), filter_traces(traces).pretty_inspect

    assert traces[1].key?('Backtrace')

    assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
    assert_equal "entry",                      traces[1]['Label'], "entry event label"
    assert_equal "pushq",                      traces[1]['Spec']
    assert_equal "resque",                     traces[1]['Flavor']
    assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
    assert_equal "critical",                   traces[1]['Queue']
    assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
    assert_equal "exit",                       traces[4]['Label'], "exit event label"

    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-client" }.size, "client layers missing \n#{filter_traces(traces).pretty_inspect}"
    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-worker" }.size, "worker layers missing \n#{filter_traces(traces).pretty_inspect}"
  end

  it 'obey_log_args_when_false' do
    SolarWindsAPM::Config[:resqueclient][:log_args] = false

    # Queue up a job to be run
    SolarWindsAPM::SDK.start_trace('resque-client_test') do
      Resque.enqueue(ResqueRemoteCallWorkerJob, [1, 2, 3])
    end
    work_off_jobs

    traces = get_all_traces

    assert_equal 12, traces.count, "traces count"
    assert same_trace_id?(traces), filter_traces(traces).pretty_inspect

    assert_equal false, traces[1].key?('Args')

    assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
    assert_equal "entry",                      traces[1]['Label'], "entry event label"
    assert_equal "pushq",                      traces[1]['Spec']
    assert_equal "resque",                     traces[1]['Flavor']
    assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
    assert_equal "critical",                   traces[1]['Queue']
    assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
    assert_equal "exit",                       traces[4]['Label'], "exit event label"

    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-client" }.size, "client layers missing \n#{filter_traces(traces).pretty_inspect}"
    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-worker" }.size, "worker layers missing \n#{filter_traces(traces).pretty_inspect}"
  end

  it 'obey_log_args_when_true' do
    SolarWindsAPM::Config[:resqueclient][:log_args] = true

    # Queue up a job to be run
    SolarWindsAPM::SDK.start_trace('resque-client_test') do
      Resque.enqueue(ResqueRemoteCallWorkerJob, 1, 2, 3)
    end
    work_off_jobs

    traces = get_all_traces

    assert_equal 12, traces.count, filter_traces(traces).pretty_inspect
    assert same_trace_id?(traces), filter_traces(traces).pretty_inspect

    assert traces[1].key?('Args')
    assert_equal "[1,2,3]", traces[1]['Args']

    assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
    assert_equal "entry",                      traces[1]['Label'], "entry event label"
    assert_equal "pushq",                      traces[1]['Spec']
    assert_equal "resque",                     traces[1]['Flavor']
    assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
    assert_equal "critical",                   traces[1]['Queue']
    assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
    assert_equal "exit",                       traces[4]['Label'], "exit event label"

    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-client" }.size, "client layers missing \n#{filter_traces(traces).pretty_inspect}"
    assert_equal 2, traces.select { |tr| tr['Layer'] == "resque-worker" }.size, "worker layers missing \n#{filter_traces(traces).pretty_inspect}"
  end


  private

  def work_off_jobs
    while (job = ::Resque.reserve(:critical))
      job.perform
    end
  end
end
