# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'


describe "Rack: " do

  before do
    @app = mock('app')
    def @app.call(_); [200, {}, "response"] ; end
    @rack = AppOpticsAPM::Rack.new(@app)
  end

  describe "when there is no context" do

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

  # the following is a common situation for grape, which, when instrumented, calls AppOpticsAPM::Rack#call 3 times
  describe "when we are tracing and the layer is rack" do

    it "should call the app_call method" do
      @rack.expects(:call_app)

      AppOpticsAPM::API.start_trace(:rack) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
      refute AppOpticsAPM::Context.isValid
    end

    it "should call the app's call method" do
      @app.expects(:call)
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::API.start_trace(:rack) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
      refute AppOpticsAPM::Context.isValid
    end
  end

  describe "when there is a context" do

    it "should log a an entry and exit" do
      AppOpticsAPM::API.expects(:log_entry)
      AppOpticsAPM::API.expects(:log_exit)
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      AppOpticsAPM::API.start_trace(:other) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
      refute AppOpticsAPM::Context.isValid
    end

    it " should log exit even when there is an exception" do
      AppOpticsAPM::API.expects(:log_exit)

      assert_raises StandardError do
        AppOpticsAPM::API.start_trace(:other) do
          def @app.call(_); raise StandardError; end
          @rack.call({})
          assert AppOpticsAPM::Context.isValid
        end
      end
      refute AppOpticsAPM::Context.isValid
    end

    it "should call the app's call method" do
      @app.expects(:call)

      AppOpticsAPM::API.start_trace(:other) do
        @rack.call({})
        assert AppOpticsAPM::Context.isValid
      end
      refute AppOpticsAPM::Context.isValid
    end

  end

end