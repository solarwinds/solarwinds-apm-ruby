# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'

# Cases:
# 1) tracing_mode: never?  => call app
# 2) tracing_mode: always, dnt: true?  => call app
# 3) --#--, dnt: false, context: tracing && layer: rack?  => call app
# 4a) --#--, not(context: tracing && layer: rack?), tracing disabled for path =>
# 4) --#--, , context: valid?  => trace + call app
# 5) --#--, context: not valid   => metrics + trace + call app
#
# A) context: tracing && layer: rack?  => #call_app
# B) not(context: tracing && layer: rack?), asset? true  => #call_app
# C) --#--, asset? false, never? true => #tracing_disabled_call
# D) --#--, never? false, tracing_disabled? true => #tracing_disabled_call
# E) --#--, tracing_disabled? false, context.valid? true => #sampling_call
# F) --#--, context.valid? false => #metrics_sampling_call

describe "Rack: " do

  def restart_rack
    @rack = AppOpticsAPM::Rack.new(@app)
  end

  before do
    @tracing_mode = AppOpticsAPM::Config.tracing_mode
    @dnt = AppOpticsAPM::Config.dnt_compiled
    @transactions = deep_dup(AppOpticsAPM::Config[:transaction_settings])

    @app = mock('app')
    def @app.call(_); [200, {}, "response"] ; end
    @rack = AppOpticsAPM::Rack.new(@app)
  end

  after do
    AppOpticsAPM::Config.tracing_mode = @tracing_mode
    AppOpticsAPM::Config.dnt_compiled = @dnt
    AppOpticsAPM::Config[:transaction_settings] = deep_dup(@transactions)
  end

  # the following is a common situation for grape, which,
  # when instrumented, calls AppOpticsAPM::Rack#call 3 times
  describe 'A - when we are tracing and the layer is rack' do
    it 'calls #app_call' do
      @rack.expects(:call_app)

      AppOpticsAPM::API.start_trace(:rack) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
      refute AppOpticsAPM::Context.isValid
    end

    it "calls the app's call method but not createHttpSpan" do
      @app.expects(:call)
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::API.start_trace(:rack) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
      refute AppOpticsAPM::Context.isValid
    end
  end

  describe 'B - asset?' do
    it 'ignores dnt if there is no :dnt_compiled' do
      AppOpticsAPM::API.expects(:log_start)
      AppOpticsAPM::Span.expects(:createHttpSpan)

      AppOpticsAPM::Config.dnt_compiled = nil

      @rack.call({})

      refute AppOpticsAPM::Context.isValid
    end

    it 'does not send metrics/traces when dnt matches' do
      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::Config.dnt_compiled = Regexp.new('.*test$')

      restart_rack
      @rack.call({ 'PATH_INFO' => '/blablabla/test' })

      refute AppOpticsAPM::Context.isValid
    end

    it 'sends metrics/traces when dnt does not match' do
      AppOpticsAPM::API.expects(:log_start).once
      AppOpticsAPM::Span.expects(:createHttpSpan).once

      AppOpticsAPM::Config.dnt_compiled = Regexp.new('.*rainbow$')

      restart_rack
      @rack.call({ 'PATH_INFO' => '/blablabla/test' })

      refute AppOpticsAPM::Context.isValid
    end
  end

  describe 'C - when tracing_mode is never' do
    it 'does not send metrics or traces' do
      @app.expects(:call).returns([200, {}, ''])
      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::Config.tracing_mode = :never
      @rack.call({})

      refute AppOpticsAPM::Context.isValid
    end

    it 'calls #tracing_disabled_call' do
      @rack.expects(:tracing_disabled_call)

      AppOpticsAPM::Config.tracing_mode = :never
      @rack.call({})
    end
  end

  describe 'D - tracing disabled for path' do
    it 'calls #tracing_disabled_call when disabled' do
      @rack.expects(:tracing_disabled_call)

      AppOpticsApm::Config[:transaction_settings] = [{ regexp: /this_one/ }]
      @rack.call({ 'PATH_INFO' => '/this_one/test' })
    end

    it 'does not call #tracing_disabled_call when not disabled' do
      @rack.expects(:tracing_disabled_call).never

      AppOpticsApm::Config[:transaction_settings] = [{ regexp: /that/ }]
      @rack.call({ 'PATH_INFO' => '/this_one/test' })
    end

    it 'does not send metrics and traces when disabled' do
      @app.expects(:call).returns([200, {}, ''])
      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsApm::Config[:transaction_settings] = [{ regexp: /this_one/ }]
      @rack.call({ 'PATH_INFO' => '/this_one/test' })

      refute AppOpticsAPM::Context.isValid
    end

    it 'sends metrics and traces when not disabled' do
      @app.expects(:call).returns([200, {}, ''])
      AppOpticsAPM::API.expects(:log_start)
      AppOpticsAPM::Span.expects(:createHttpSpan)

      AppOpticsApm::Config[:transaction_settings] = [{ regexp: /that/ }]
      @rack.call({ 'PATH_INFO' => '/this_one/test' })

      refute AppOpticsAPM::Context.isValid
    end
  end

  describe 'E - when there is a context' do

    it 'should log a an entry and exit' do
      AppOpticsAPM::API.expects(:log_entry)
      AppOpticsAPM::API.expects(:log_exit)
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::API.start_trace(:other) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
    end

    it 'should log exit even when there is an exception' do
      AppOpticsAPM::API.expects(:log_exit)

      assert_raises StandardError do
        AppOpticsAPM::API.start_trace(:other) do
          def @app.call(_); raise StandardError; end
          @rack.call({})
          assert AppOpticsAPM::Context.isValid
        end
      end
    end

    it "should call the app's call method" do
      @app.expects(:call)

      AppOpticsAPM::API.start_trace(:other) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
    end

  end

  describe 'F - when there is no context' do

    it 'should start/end a trace and send metrics' do
      AppOpticsAPM::API.expects(:log_start)
      AppOpticsAPM::API.expects(:log_end)
      AppOpticsAPM::Span.expects(:createHttpSpan)

      @rack.call({})

      refute AppOpticsAPM::Context.isValid
    end

    it 'should start/end a trace and send metrics when there is an exception' do
      def @app.call(_); raise StandardError; end

      AppOpticsAPM::API.expects(:log_start)
      AppOpticsAPM::API.expects(:log_end)
      AppOpticsAPM::Span.expects(:createHttpSpan)

      assert_raises StandardError do
        @rack.call({})
      end

      refute AppOpticsAPM::Context.isValid
    end

    it "should call the app's call method" do
      @app.expects(:call)

      @rack.call({})
      refute AppOpticsAPM::Context.isValid
    end

  end

end