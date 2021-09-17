# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'

describe "Rack: " do

  ##
  # HELPER METHODS
  #
  # method name = <name>_<xtrace_tracing_tag>_<expectations for start/exit/HttpSpan>
  def check_01_111(env = {})

    _, headers, _ = @rack.call(env)
    assert AppOpticsAPM::XTrace.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    assert AppOpticsAPM::XTrace.sampled?(headers['X-Trace']), 'X-Trace in headers must be sampled'
    refute AppOpticsAPM::Context.isValid, 'Context after call should not be valid'

    traces = get_all_traces

    assert_equal 2, traces.size
    assert_equal headers['X-Trace'], traces[1]['X-Trace']

    AppOpticsAPM::API.expects(:log_start).once
    AppOpticsAPM::API.expects(:log_exit).once
    AppOpticsAPM::Span.expects(:createHttpSpan).once
    @rack.call(env)
  end

  def check_00_000(env = {})

    _, headers, _ = @rack.call(env)
    assert AppOpticsAPM::XTrace.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    refute AppOpticsAPM::XTrace.sampled?(headers['X-Trace']), 'X-Trace in headers should NOT be sampled'
    refute AppOpticsAPM::Context.isValid, 'Context after call should not be valid'

    traces = get_all_traces
    assert traces.empty?, "No traces should have been recorded"

    AppOpticsAPM::API.expects(:log_start).never
    AppOpticsAPM::API.expects(:log_exit).never
    AppOpticsAPM::Span.expects(:createHttpSpan).never
    @rack.call(env)
  end

  def check_00_001(env = {})

    _, headers, _ = @rack.call(env)
    assert AppOpticsAPM::XTrace.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    refute AppOpticsAPM::XTrace.sampled?(headers['X-Trace']), 'X-Trace in headers should NOT be sampled'
    refute AppOpticsAPM::Context.isValid, 'Context after call should not be valid'

    traces = get_all_traces
    assert traces.empty?, "No traces should have been recorded"

    AppOpticsAPM::API.expects(:log_start).never
    AppOpticsAPM::API.expects(:log_exit).never
    AppOpticsAPM::Span.expects(:createHttpSpan).once
    @rack.call(env)
  end

  def check_rescue_none_111(env = {})

    begin
      @rack.call(env)
    rescue
    end

    refute AppOpticsAPM::Context.isValid, 'Context after call should not be valid'

    traces = get_all_traces
    assert_equal 3, traces.size
    assert_equal 'error', traces[1]['Label']

    AppOpticsAPM::API.expects(:log_start).once
    AppOpticsAPM::API.expects(:log_exit).once
    AppOpticsAPM::Span.expects(:createHttpSpan).once
    begin
      @rack.call(env)
    rescue
    end
  end

  def check_w_context_01_110(env = {})
    AppOpticsAPM::Reporter.clear_all_traces if ENV['APPOPTICS_REPORTER'] == 'file'

    _, headers, _ = @rack.call(env)
    assert AppOpticsAPM::XTrace.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    assert AppOpticsAPM::XTrace.sampled?(headers['X-Trace']), 'X-Trace in headers must be sampled'
    assert AppOpticsAPM::Context.isValid, 'Context after call should be valid'

    traces = get_all_traces
    assert_equal 2, traces.size
    assert_equal headers['X-Trace'], traces[1]['X-Trace']

    AppOpticsAPM::API.expects(:log_start).once
    AppOpticsAPM::API.expects(:log_exit).once
    AppOpticsAPM::Span.expects(:createHttpSpan).never
    @rack.call(env)
  end

  def check_w_context_00_000(env = {})
    AppOpticsAPM::Reporter.clear_all_traces if ENV['APPOPTICS_REPORTER'] == 'file'

    _, headers, _ = @rack.call(env)
    assert AppOpticsAPM::XTrace.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    refute AppOpticsAPM::XTrace.sampled?(headers['X-Trace']), 'X-Trace in headers must be sampled'
    assert AppOpticsAPM::Context.isValid, 'Context after call should be valid'

    traces = get_all_traces
    assert traces.empty?

    AppOpticsAPM::API.expects(:log_start).never
    AppOpticsAPM::API.expects(:log_exit).never
    AppOpticsAPM::Span.expects(:createHttpSpan).never
    @rack.call(env)
  end

  def check_w_context_none_000(env = {})
    AppOpticsAPM::Reporter.clear_all_traces if ENV['APPOPTICS_REPORTER'] == 'file'

    _, headers, _ = @rack.call(env)

    refute headers.key?('X-Trace'), 'There should not be an X-Trace in headers'
    assert AppOpticsAPM::Context.isValid, 'Context after call should be valid'

    traces = get_all_traces
    assert traces.empty?, "No traces should have been recorded"

    AppOpticsAPM::API.expects(:log_start).never
    AppOpticsAPM::API.expects(:log_exit).never
    AppOpticsAPM::Span.expects(:createHttpSpan).never
    @rack.call(env)
  end

  def restart_rack
    @rack = AppOpticsAPM::Rack.new(@app)
  end

  module AppOpticsAPM
    module Config
      def self.delete(config)
        @@config.delete(config)
      end
    end
  end

  before do
    clear_all_traces
    @tr_mode = AppOpticsAPM::Config.tracing_mode
    @dnt = AppOpticsAPM::Config.dnt_compiled
    @tr_settings = AppOpticsAPM::Util.deep_dup(AppOpticsAPM::Config[:transaction_settings])
    @profiling = AppOpticsAPM::Config[:profiling]

    @app = mock('app')
    def @app.call(_)
      [200, {}, "response"]
    end
    @rack = AppOpticsAPM::Rack.new(@app)
  end

  after do
    AppOpticsAPM::Config[:tracing_mode] = @tr_mode
    AppOpticsAPM::Config[:dnt_compiled] = @dnt
    AppOpticsAPM::Config[:transaction_settings] = AppOpticsAPM::Util.deep_dup(@tr_settings)
    AppOpticsAPM::Config[:profiling] = @profiling
  end

  # A and B implement the acceptance tests as outlined in the google doc
  describe 'A - tracing mode :enabled' do
    before do
      AppOpticsAPM::Config.tracing_mode = :enabled
      AppOpticsAPM::Config[:transaction_settings] = {
        url: [{ extensions: ['jpg', 'css'] },
              { regexp: '^.*\/long_job\/.*$',
                opts: Regexp::IGNORECASE,
                tracing: :disabled }]
      }
    end

    it '1 - no transaction settings' do
      AppOpticsAPM::Config.delete(:transaction_settings)

      check_01_111
    end

    it '2 - :disabled transaction settings not matched' do
      check_01_111
    end

    it '3 - :disabled transaction settings matched' do
      check_00_000(
        { 'PATH_INFO' => '/long_job/' }
      )
    end

    it '4 - sampling xtrace + :disabled transaction settings not matched' do
      check_01_111(
        { 'HTTP_TRACEPARENT' => '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01' }
      )
    end

    it '5 - sampling xtrace + :disabled transaction settings matched' do
      check_00_000(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFB01'
        }
      )
    end

    it '6 - non-sampling xtrace + :disabled transaction settings not matched' do
      check_00_001(
        { 'HTTP_TRACEPARENT' => '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC00' }
      )
    end

    it '7 - non-sampling xtrace + :disabled transaction settings matched' do
      check_00_000(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFD00'
        }
      )
    end
  end

  describe 'B - tracing mode :disabled' do
    before do
      AppOpticsAPM::Config.tracing_mode = :disabled
      AppOpticsAPM::Config[:transaction_settings] = {
        url: [{ extensions: ['jpg', 'css'],
                tracing: :enabled },
              { regexp: '^.*\/long_job\/.*$',
                opts: Regexp::IGNORECASE,
                tracing: :enabled }]
      }
    end

    it '1 - no transaction settings' do
      AppOpticsAPM::Config.delete(:transaction_settings)

      check_00_000
    end

    it '2 - :enabled transaction settings not matched' do
      check_00_000
    end

    it '3 - :enabled transaction settings matching' do
      check_01_111(
        { 'PATH_INFO' => '/long_job/' }
      )
    end

    it '4 - sampling xtrace + :enabled  transaction settings not matching' do
      check_00_000(
        { 'HTTP_TRACEPARENT' => '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01' }
      )
    end

    it '5 - sampling xtrace + :enabled transaction settings matching' do
      check_01_111(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFB01'
        }
      )
    end

    it '6 - non-sampling xtrace + :enabled transaction settings not matching' do
      check_00_000(
        { 'HTTP_TRACEPARENT' => '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC00' }
      )
    end

    it '7 - non-sampling xtrace + :enabled transaction settings matching' do
      check_00_001(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFD00'
        }
      )
    end
  end

  describe 'C - with exceptions' do

    it 'should start/end a trace and send metrics when there is an exception' do
      def @app.call(_); raise StandardError; end

      check_rescue_none_111
    end

  end

  # the following is a common situation for grape, which,
  # when instrumented, calls AppOpticsAPM::Rack#call 3 times
  describe 'D - with context and current layer is :rack' do
    it 'calls @app.call' do
      @rack.app.expects(:call)

      AppOpticsAPM::API.start_trace(:rack) do
        @rack.call({})
      end
    end

    it "does not sample, do metrics, nor return X-Trace header" do
      AppOpticsAPM::API.start_trace(:rack) do
        check_w_context_none_000
      end
    end
  end

  describe 'E - when there is a context NOT from rack' do

    # skipping, repetition of first test in D
    # it "should call the app's call method" do
    #   @rack.app.expects(:call)
    #
    #   AppOpticsAPM::API.start_trace(:other) do
    #     @rack.call({})
    #   end
    # end

    it 'should sample but not do metrics' do
      AppOpticsAPM::API.start_trace(:other) do
        check_w_context_01_110
      end
    end

    # TODO this may be the test that makes the test suite flaky
    # it 'should log an error' do
    #   AppOpticsAPM::API.expects(:log_start)
    #   AppOpticsAPM::API.expects(:log_exception)
    #   AppOpticsAPM::API.expects(:log_exit)
    #   AppOpticsAPM::Span.expects(:createHttpSpan).never
    #
    #   AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')
    #
    #   assert_raises StandardError do
    #     def @app.call(_); raise StandardError; end
    #     @rack.call({})
    #   end
    # end

    it 'returns a non sampling header when there is a non-sampling context' do
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

      check_w_context_00_000
    end

    # it 'does not trace or send metrics when there is a non-sampling context' do
    #   AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')
    #
    #   AppOpticsAPM::API.expects(:log_start).never
    #   AppOpticsAPM::Span.expects(:createHttpSpan).never
    #
    #   @rack.call({})
    # end
  end

  describe 'F - asset?' do
    it 'ignores dnt if there is no :dnt_compiled' do
      AppOpticsAPM::API.expects(:log_start).twice
      AppOpticsAPM::Span.expects(:createHttpSpan).twice

      AppOpticsAPM::Config.dnt_compiled = nil

      _, headers_1, _ = @rack.call({})
      _, headers_2, _ = @rack.call({ 'PATH_INFO' => '/blablabla/test' })

      AppOpticsAPM::XTrace.valid?(headers_1['X-Trace'])
      AppOpticsAPM::XTrace.valid?(headers_2['X-Trace'])
      refute AppOpticsAPM::Context.isValid
    end

    it 'does not send metrics/traces when dnt matches' do
      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::Config.dnt_compiled = Regexp.new('.*test$')
      restart_rack

      _, headers, _ = @rack.call({ 'PATH_INFO' => '/blablabla/test' })

      refute headers['X-Trace']
      refute AppOpticsAPM::Context.isValid
    end

    it 'sends metrics/traces when dnt does not match' do
      AppOpticsAPM::API.expects(:log_start).once
      AppOpticsAPM::Span.expects(:createHttpSpan).once

      AppOpticsAPM::Config.dnt_compiled = Regexp.new('.*rainbow$')
      restart_rack

      _, headers, _ = @rack.call({ 'PATH_INFO' => '/blablabla/test' })

      AppOpticsAPM::XTrace.valid?(headers['X-Trace'])
      refute AppOpticsAPM::Context.isValid
    end
  end

  describe 'G - ProfileSpans KV' do
    it 'sets it to 1 if profiling is enabled' do
      AppOpticsAPM::Config['profiling'] = :enabled
      @rack.call({})
      traces = get_all_traces

      assert_equal 1, traces.last['ProfileSpans']
    end

    it 'sets it to -1 if profiling is disabled' do
      AppOpticsAPM::Config['profiling'] = :disabled
      @rack.call({})
      traces = get_all_traces

      assert_equal -1, traces.last['ProfileSpans']
    end

    it 'sets it to -1 if the profiling config is anything else than :enabled' do
      AppOpticsAPM::Config['profiling'] = :boo
      @rack.call({})
      traces = get_all_traces

      assert_equal -1, traces.last['ProfileSpans']
    end

    it 'sets it to -1 if there is not profiling config' do
      AppOpticsAPM::Config.delete(:profiling)

      @rack.call({})
      traces = get_all_traces

      assert_equal -1, traces.last['ProfileSpans']
    end
  end
end
