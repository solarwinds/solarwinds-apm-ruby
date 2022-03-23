# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require_relative "../jobs/resque/remote_call_worker_job"
  require_relative "../jobs/resque/error_worker_job"

  Resque.redis = Redis.new(:host => ENV['REDIS_HOST'] || ENV['REDIS_SERVER'] || '127.0.0.1',
                           :password => ENV['REDIS_PASSWORD'] || 'secret_pass')

  Resque.enqueue(ResqueRemoteCallWorkerJob) # calling this here once to avoid other calls having an auth span

  describe 'ResqueClient' do
    before do
      clear_all_traces
      @collect_backtraces = SolarWindsAPM::Config[:resqueclient][:collect_backtraces]
      @log_args = SolarWindsAPM::Config[:resqueclient][:log_args]
    end

    after do
      SolarWindsAPM::Config[:resqueclient][:collect_backtraces] = @collect_backtraces
      SolarWindsAPM::Config[:resqueclient][:log_args] = @log_args
    end

    it 'sw_apm_methods_defined' do
      [:enqueue, :enqueue_to, :dequeue].each do |m|
        assert_equal true, ::Resque.method_defined?("#{m}_with_sw_apm")
      end

      assert_equal true, ::Resque::Worker.method_defined?("perform_with_sw_apm")
      assert_equal true, ::Resque::Job.method_defined?("fail_with_sw_apm")
    end

    def not_tracing_validation
      assert_equal true, Resque.enqueue(ResqueRemoteCallWorkerJob), "not tracing; enqueue return value"
      assert_equal true, Resque.enqueue(ResqueRemoteCallWorkerJob, 1, 2, "3"), "not tracing; enqueue extra params"
    end

    it 'enqueue' do
      SolarWindsAPM::SDK.start_trace('resque-client_test') do
        Resque.enqueue(ResqueRemoteCallWorkerJob)
      end

      traces = get_all_traces

      assert_equal 6, traces.count, "trace count"
      validate_outer_layers(traces, 'resque-client_test')

      assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
      assert_equal "entry",                      traces[1]['Label'], "entry event label"
      assert_equal "pushq",                      traces[1]['Spec']
      assert_equal "resque",                     traces[1]['Flavor']
      assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
      assert_equal "critical",                   traces[1]['Queue']
      assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
      assert_equal "exit",                       traces[4]['Label'], "exit event label"
    end

    it 'dequeue' do
      SolarWindsAPM::SDK.start_trace('resque-client_test') do
        Resque.dequeue(ResqueRemoteCallWorkerJob, { :generate => :moped })
      end

      traces = get_all_traces

      assert_equal 6, traces.count, "trace count"
      validate_outer_layers(traces, 'resque-client_test')

      assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
      assert_equal "entry",                      traces[1]['Label'], "entry event label"
      assert_equal "pushq",                      traces[1]['Spec']
      assert_equal "resque",                     traces[1]['Flavor']
      assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
      assert_equal "critical",                   traces[1]['Queue']
      assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
      assert_equal "exit",                        traces[4]['Label'], "exit event label"
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

      traces = get_all_traces

      assert_equal 6, traces.count, "trace count"
      validate_outer_layers(traces, 'resque-client_test')

      assert_equal false, traces[1].key?('Backtrace')

      assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
      assert_equal "entry",                      traces[1]['Label'], "entry event label"
      assert_equal "pushq",                      traces[1]['Spec']
      assert_equal "resque",                     traces[1]['Flavor']
      assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
      assert_equal "critical",                   traces[1]['Queue']
      assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
      assert_equal "exit",                       traces[4]['Label'], "exit event label"
    end

    it 'obey_collect_backtraces_when_true' do
      SolarWindsAPM::Config[:resqueclient][:collect_backtraces] = true

      # Queue up a job to be run
      SolarWindsAPM::SDK.start_trace('resque-client_test') do
        Resque.enqueue(ResqueRemoteCallWorkerJob, [1, 2, 3])
      end

      traces = get_all_traces

      assert_equal 6, traces.count, "trace count"
      validate_outer_layers(traces, 'resque-client_test')

      assert_equal true, traces[1].key?('Backtrace')

      assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
      assert_equal "entry",                      traces[1]['Label'], "entry event label"
      assert_equal "pushq",                      traces[1]['Spec']
      assert_equal "resque",                     traces[1]['Flavor']
      assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
      assert_equal "critical",                   traces[1]['Queue']
      assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
      assert_equal "exit",                       traces[4]['Label'], "exit event label"
    end

    it 'obey_log_args_when_false' do
      SolarWindsAPM::Config[:resqueclient][:log_args] = false

      # Queue up a job to be run
      SolarWindsAPM::SDK.start_trace('resque-client_test') do
        Resque.enqueue(ResqueRemoteCallWorkerJob, [1, 2, 3])
      end

      traces = get_all_traces

      assert_equal 6, traces.count, "trace count"
      validate_outer_layers(traces, 'resque-client_test')

      assert_equal false, traces[1].key?('Args')

      assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
      assert_equal "entry",                      traces[1]['Label'], "entry event label"
      assert_equal "pushq",                      traces[1]['Spec']
      assert_equal "resque",                     traces[1]['Flavor']
      assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
      assert_equal "critical",                   traces[1]['Queue']
      assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
      assert_equal "exit",                       traces[4]['Label'], "exit event label"
    end

    it 'obey_log_args_when_true' do
      SolarWindsAPM::Config[:resqueclient][:log_args] = true

      # Queue up a job to be run
      SolarWindsAPM::SDK.start_trace('resque-client_test') do
        Resque.enqueue(ResqueRemoteCallWorkerJob, 1, 2, 3)
      end

      traces = get_all_traces

      assert_equal 6, traces.count, "trace count"
      validate_outer_layers(traces, 'resque-client_test')

      assert_equal true, traces[1].key?('Args')
      assert_equal "[1,2,3]", traces[1]['Args']

      assert_equal "resque-client",              traces[1]['Layer'], "entry event layer name"
      assert_equal "entry",                      traces[1]['Label'], "entry event label"
      assert_equal "pushq",                      traces[1]['Spec']
      assert_equal "resque",                     traces[1]['Flavor']
      assert_equal "ResqueRemoteCallWorkerJob",  traces[1]['JobName']
      assert_equal "critical",                   traces[1]['Queue']
      assert_equal "resque-client",              traces[4]['Layer'], "exit event layer name"
      assert_equal "exit",                       traces[4]['Label'], "exit event label"
    end
  end
end
