# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'

# Cases:
# 1) tracing_mode: never?  => call app
# 2) tracing_mode: always, dnt: true?  => call app
# 3) --#--, dnt: false, context: tracing && layer: rack?  => call app
# 4) --#--, not(context: tracing && layer: rack?), context: valid?  => trace + call app
# 5) --#--, context: not valid   => metrics + trace + call app

describe "Rack: " do

  def restart_rack
    @rack = AppOpticsAPM::Rack.new(@app)
  end

  before do
    @tracing_mode = AppOpticsAPM::Config.tracing_mode
    @dnt = AppOpticsAPM::Config.dnt_compiled

    @app = mock('app')
    def @app.call(_); [200, {}, "response"] ; end
    @rack = AppOpticsAPM::Rack.new(@app)
  end

  after do
    AppOpticsAPM::Config.tracing_mode = @tracing_mode
    AppOpticsAPM::Config.dnt_compiled = @dnt
  end

  describe '1 - when tracing_mode is never' do
    it 'does not send metrics or traces' do
      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::Config.tracing_mode = :never

      @rack.call({})

      refute AppOpticsAPM::Context.isValid
    end

  end

  describe '2 - DNT - do not trace' do
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

  # the following is a common situation for grape, which, when instrumented, calls AppOpticsAPM::Rack#call 3 times
  describe "3 - when we are tracing and the layer is rack" do

    it "should call the app_call method" do
      @rack.expects(:call_app)

      AppOpticsAPM::API.start_trace(:rack) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
      refute AppOpticsAPM::Context.isValid
    end

    it "should call the app's call method but not createHttpSpan" do
      @app.expects(:call)
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::API.start_trace(:rack) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
      refute AppOpticsAPM::Context.isValid
    end
  end

  describe "4 - when there is a context" do

    it "should log a an entry and exit" do
      AppOpticsAPM::API.expects(:log_entry)
      AppOpticsAPM::API.expects(:log_exit)
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::API.start_trace(:other) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
    end

    it "should log exit even when there is an exception" do
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

  describe "5 - when there is no context" do

    it "should start/end a trace and send metrics" do
      AppOpticsAPM::API.expects(:log_start)
      AppOpticsAPM::API.expects(:log_end)
      AppOpticsAPM::Span.expects(:createHttpSpan)

      @rack.call({})

      refute AppOpticsAPM::Context.isValid
    end

    it "should start/end a trace and send metrics when there is an exception" do
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