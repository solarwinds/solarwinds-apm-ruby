# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'
require 'openssl'

# Minitest::Test.i_suck_and_my_tests_are_order_dependent!
describe "Rack Trigger Tracing " do
  # Minitest::Test.i_suck_and_my_tests_are_order_dependent!

  def restart_rack
    @rack = SolarWindsAPM::Rack.new(@app)
  end

  def create_signature(options)
    key = '8mZ98ZnZhhggcsUmdMbS'
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), key, options)
  end

  before do
    clear_all_traces

    @collect_bt = SolarWindsAPM::Config[:rack][:collect_backtraces]
    SolarWindsAPM::Config[:rack][:collect_backtraces] = false

    @t_mode =  SolarWindsAPM::Config[:tracing_mode]
    @tt_mode = SolarWindsAPM::Config[:trigger_tracing_mode]

    @app = mock('app')
    def @app.call(_)
      [200, {}, "response"]
    end
    @rack = SolarWindsAPM::Rack.new(@app)
  end

  after do
    SolarWindsAPM::Config[:rack][:collect_backtraces] = @collect_bt
    SolarWindsAPM::Config[:tracing_mode] = @t_mode
    SolarWindsAPM::Config[:trigger_tracing_mode] = @tt_mode
  end

  describe 'settings not available' do
    # can't test this here
  end

  describe 'tracing disabled' do
    before do
      SolarWindsAPM::Config[:tracing_mode] = :disabled
    end

    it 'does not trigger trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_equal 'trigger-trace=tracing-disabled', res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end

    it 'does not trigger trace with signature' do
      options = "trigger-trace;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=tracing-disabled/, res_headers['X-Trace-Options-Response']
      assert_match /auth=not-checked/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end

    it 'complains about bad timestamp' do
      options = "trigger-trace;ts=12345"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=tracing-disabled/, res_headers['X-Trace-Options-Response']
      assert_match /auth=not-checked/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end
  end

  describe 'ok without signature' do
    it 'still works with normal traces' do
      req_headers = { }
      @rack.call(req_headers)

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?
        refute traces[0]['TriggerTrace']
      end
    end

    it 'triggers a trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_equal 'trigger-trace=ok', res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?
        assert_equal 'true', traces[0]['TriggeredTrace']
      end
    end

    it 'triggers a trace and reports SWKeys' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace;sw-keys=lo:se,check-id:123' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_equal 'trigger-trace=ok', res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?
        assert_equal 'true', traces[0]['TriggeredTrace']
        assert_equal 'lo:se,check-id:123', traces[0]['SWKeys']
      end
    end

    it 'triggers a trace and reports and ignores kvs' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace;sw-keys=lo:se,check-id:123;custom-foo=bar;not-valid-option=no-foo' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_equal 'trigger-trace=ok;ignored=not-valid-option', res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?
        assert_equal 'true', traces[0]['TriggeredTrace']
        assert_equal 'lo:se,check-id:123', traces[0]['SWKeys']
        assert_equal 'bar', traces[0]['custom-foo']
      end
    end
  end

  describe 'ok WITH signature' do
    it 'still works with normal traces' do
      options = "ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      @rack.call(req_headers)

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?
        refute traces[0]['TriggerTrace']
      end
    end

    it 'triggers a trace' do
      options = "trigger-trace;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /auth=ok/, res_headers['X-Trace-Options-Response']
      assert_match /trigger-trace=ok/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?
        assert_equal 'true', traces[0]['TriggeredTrace']
      end
    end

    it 'triggers a trace and reports and ignores kvs' do
      options = "trigger-trace;sw-keys=lo:se,check-id:123;custom-foo=bar;not-valid-option=no-foo;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /auth=ok/, res_headers['X-Trace-Options-Response']
      assert_match /trigger-trace=ok/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=not-valid-option/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?
        assert_equal 'true', traces[0]['TriggeredTrace']
        assert_equal 'lo:se,check-id:123', traces[0]['SWKeys']
        assert_equal 'bar', traces[0]['custom-foo']
      end
    end
  end

  describe '"ok" with BAD signature' do
    it 'bad signature with normal tracing' do
      options = "ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature.gsub(/\d/, 'a')
      }

      @rack.call(req_headers)

      traces = get_all_traces
      assert traces.empty?
    end

    it 'bad signature with simple trigger trace request' do
      options = "trigger-trace;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature + "bad"
      }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /auth=bad-signature/, res_headers['X-Trace-Options-Response']
      refute_match /trigger-trace/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end

    it 'bad timestamp with complex options header' do
      options = "trigger-trace;sw-keys=lo:se,check-id:123;custom-foo=bar;not-valid-option=no-foo;ts=12345"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /auth=bad-timestamp/, res_headers['X-Trace-Options-Response']
      refute_match /trigger-trace/, res_headers['X-Trace-Options-Response']
      refute_match /ignored/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end
  end

  describe 'trigger tracing mode disabled' do
    # assuming remote settings are enabled
    # can't test remote setting disabled here
    before do
      SolarWindsAPM::Config[:trigger_tracing_mode] = :disabled
    end

    it 'does not trigger trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace;bad-key' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=trigger-tracing-disabled/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=bad-key/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end

    it 'does not trigger trace with signature' do
      options = "trigger-trace;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=trigger-tracing-disabled/, res_headers['X-Trace-Options-Response']
      assert_match /auth=ok/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end

    it 'does not trigger trace with bad signature' do
      options = "trigger-trace;bad-key=bad-val;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature.gsub(/\d/, 'a')
      }

      _, res_headers, _ = @rack.call(req_headers)
      refute_match /trigger-trace=trigger-tracing-disabled/, res_headers['X-Trace-Options-Response']
      assert_match /auth=bad-signature/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end
  end

  describe 'rate exceeded' do
  # remote setting can't test here
  end

  describe 'not requested' do
    it 'adds response and kvs to normal trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'sw-keys=lo:se,check-id:123;custom-foo=bar' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=not-requested/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?

        assert_equal 'bar', traces[0]['custom-foo']
        assert_equal 'lo:se,check-id:123', traces[0]['SWKeys']
      end
    end

    it 'adds ignored trigger-trace key' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace=1;sw-keys=lo:se,check-id:123;custom-foo=bar' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=not-requested/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=trigger-trace/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?, "There should be traces"

        assert_equal 'bar', traces[0]['custom-foo']
        assert_equal 'lo:se,check-id:123', traces[0]['SWKeys']
      end
    end

    it 'adds response and kvs to normal trace with signature' do
      options = "ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      _, res_headers, _ = @rack.call(req_headers)
      assert_match /trigger-trace=not-requested/, res_headers['X-Trace-Options-Response']
      assert_match /auth=ok/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?, "There should be traces"
      end
    end

    it 'adds ignored trigger-trace key with signature' do
      options = "trigger-trace=1;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      _, res_headers, _ = @rack.call(req_headers)
      assert_match /trigger-trace=not-requested/, res_headers['X-Trace-Options-Response']
      assert_match /auth=ok/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=trigger-trace/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?, "There should be traces"
      end
    end

    it 'complains about bad signature' do
      options = "bad-key;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature.gsub(/\d/, 'a')
      }

      _, res_headers, _ = @rack.call(req_headers)
      refute_match /trigger-trace=not-requested/, res_headers['X-Trace-Options-Response']
      assert_match /auth=bad-signature/, res_headers['X-Trace-Options-Response']
      refute_match /ignored/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end
  end

  describe 'incoming traceparent' do
    it 'trigger-trace and sampling x-trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace;sw-keys=lo:se,check-id:123;custom-foo=bar;bad-key',
                      'HTTP_TRACEPARENT' => '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01',
                      'HTTP_TRACESTATE' => 'sw=49e60702469db05f-01' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=ignored/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=bad-key/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?, "There should be traces"
        assert_equal 'lo:se,check-id:123', traces[0]['SWKeys']
        assert_equal 'bar', traces[0]['custom-foo']
      end
    end

    it 'no trigger-trace and sampling x-trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'sw-keys=lo:se,check-id:123;custom-foo=bar;bad-key',
                      'HTTP_TRACEPARENT' => '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01',
                      'HTTP_TRACESTATE' => 'sw=49e60702469db05f-01' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=not-requested/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=bad-key/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?, "There should be traces"
        assert_equal 'lo:se,check-id:123', traces[0]['SWKeys']
        assert_equal 'bar', traces[0]['custom-foo']
      end
    end

    it 'trigger-trace and non-sampling x-trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace;sw-keys=lo:se,check-id:123;custom-foo=bar;bad-key',
                      'HTTP_TRACEPARENT' => '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00',
                      'HTTP_TRACESTATE' => 'sw=49e60702469db05f-00' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=ignored/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=bad-key/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end

    it 'trigger-trace and invalid x-trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'trigger-trace;sw-keys=lo:se,check-id:123;custom-foo=bar;bad-key',
                      'HTTP_TRACEPARENT' => '00-7435a9fe510ae4f4e18-49e60702469db05f-00',
                      'HTTP_TRACESTATE' => 'sw=49e60702469db05f-00' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=ok/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=bad-key/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      if ENV['SW_AMP_REPORTER'] =='file'
        refute traces.empty?, "There should be traces"
        assert_equal 'lo:se,check-id:123', traces[0]['SWKeys']
        assert_equal 'bar', traces[0]['custom-foo']
      end
    end

    it 'TODO no trigger-trace and non-sampling x-trace' do
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => 'sw-keys=lo:se,check-id:123;custom-foo=bar;bad-key',
                      'HTTP_TRACEPARENT' => '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00',
                      'HTTP_TRACESTATE' => 'sw=49e60702469db05f-00' }

      _, res_headers, _ = @rack.call(req_headers)

      assert_match /trigger-trace=not-requested/, res_headers['X-Trace-Options-Response']
      assert_match /ignored=bad-key/, res_headers['X-Trace-Options-Response']

      traces = get_all_traces
      assert traces.empty?
    end

  end

  describe 'crazy loop' do
    it 'receives a different signature' do
      skip # this is a setup to test changing collector settings on the fly
      options = "trigger-trace;sw-keys=lo:se,check-id:123;custom-foo=bar;ts=#{Time.now.to_i}"
      signature = create_signature(options)
      req_headers = { 'HTTP_X_TRACE_OPTIONS' => options,
                      'HTTP_X_TRACE_OPTIONS_SIGNATURE' => signature
      }

      15.times do
        _, res_headers, _ = @rack.call(req_headers)

        sleep 7
      end
    end
  end
end
