# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'

class RackDNTTestApp < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use AppOpticsAPM::Rack
      map "/lobster" do
        use Rack::Lint
        run Rack::Lobster.new
      end
    }
  end

  def setup
    clear_all_traces
    @dnt_regexp = AppOpticsAPM::Config[:dnt_regexp]
    @dnt_compiled = AppOpticsAPM::Config[:dnt_compiled]
    @tr_map = AppOpticsAPM::Util.deep_dup(AppOpticsAPM::Config[:transaction_settings])
  end

  def teardown
    AppOpticsAPM::Config[:dnt_regexp] = @dnt_regexp
    AppOpticsAPM::Config[:dnt_compiled] = @dnt_compiled
    AppOpticsAPM::Config[:transaction_settings] = AppOpticsAPM::Util.deep_dup(@tr_map)
  end

  def test_custom_do_not_trace
    AppOpticsAPM::Config[:dnt_regexp] = "lobster$"

    get "/lobster"

    traces = get_all_traces
    assert traces.empty?
  end

  def test_do_not_trace_static_assets
    get "/assets/static_asset.png"

    traces = get_all_traces
    assert traces.empty?

    assert_equal 404, last_response.status
  end

  def test_do_not_trace_static_assets_with_param
    get "/assets/static_asset.png?body=1"

    traces = get_all_traces
    assert traces.empty?

    assert_equal 404, last_response.status
  end

  def test_do_not_trace_static_assets_with_multiple_params
    get "/assets/static_asset.png?body=&head="

    traces = get_all_traces
    assert traces.empty?

    assert_equal 404, last_response.status
  end

  def test_complex_do_not_trace
    # Do not trace .js files _except for_ show.js
    AppOpticsAPM::Config[:dnt_regexp] = "(\.js$)(?<!show.js)"

    # First: We shouldn't trace general .js files
    get "/javascripts/application.js"

    traces = get_all_traces
    assert traces.empty?

    # Second: We should trace show.js
    clear_all_traces

    get "/javascripts/show.js"

    traces = get_all_traces
    refute traces.empty?, 'No traces were recorded'
  end

  def test_empty_transaction_settings
    AppOpticsAPM::Config[:transaction_settings] = { url: [] }

    # TODO make this test more unit
    AppOpticsAPM::Context.expects(:getDecisions).returns([1, 1, 1000, 1, 0, -1, 1000, 1000, '', '', 0]).once
    AppOpticsAPM::Span.expects(:createHttpSpan).returns("the_transaction_name").once

    get "/lobster"

    traces = get_all_traces
    assert_equal 2, traces.size
  end

  def test_transaction_settings_regexp
    AppOpticsAPM::Config[:transaction_settings] = { url: [{ regexp: /.*LOB.*/i }] }
    AppOpticsAPM::Span.expects(:createHttpSpan).never

    get "/lobster"

    traces = get_all_traces
    assert traces.empty?

    refute AppOpticsAPM::Context.isValid
  end

  def test_transaction_settings_extensions
    AppOpticsAPM::Config[:transaction_settings] = { url: [{ extensions: ['ter'] }] }
    AppOpticsAPM::Span.expects(:createHttpSpan).never

    get "/lobster"

    traces = get_all_traces
    assert traces.empty?
  end

  def test_transaction_settings_with_x_trace
    AppOpticsAPM::Config[:transaction_settings] = { url: [{ extensions: ['ter'] }] }
    AppOpticsAPM::Span.expects(:createHttpSpan).never

    trace = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01'
    res = get "/lobster", {}, { 'HTTP_TRACEPARENT' => trace,
                                'HTTP_TRACESTATE' => "sw=49e60702469db05f-01" }

    assert_equal "#{trace[0..-2]}0", res.header['X-Trace']
    traces = get_all_traces
    assert traces.empty?

    refute AppOpticsAPM::Context.isValid
  end
end

