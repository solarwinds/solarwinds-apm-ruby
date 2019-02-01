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
    @tr_map = deep_dup(AppOpticsAPM::Config[:transaction_settings])
  end

  def teardown
    AppOpticsAPM::Config[:dnt_regexp] = @dnt_regexp
    AppOpticsAPM::Config[:dnt_compiled] = @dnt_compiled
    AppOpticsAPM::Config[:transaction_settings] = deep_dup(@tr_map)
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
    assert !traces.empty?
  end

  def test_empty_transaction_settings
    AppOpticsAPM::Config[:transaction_settings] = [{ }]
    AppOpticsAPM::Span.expects(:createHttpSpan).returns("the_transaction_name").once

    get "/lobster"

    traces = get_all_traces
    assert_equal 2, traces.size
  end

  def test_transaction_settings_regexp
    AppOpticsAPM::Config[:transaction_settings] = [{ regexp: /.*LOB.*/i }]
    AppOpticsAPM::Span.expects(:createHttpSpan).never

    get "/lobster"

    traces = get_all_traces
    assert traces.empty?

    refute AppOpticsAPM::Context.isValid
  end

  def test_transaction_settings_extensions
    AppOpticsAPM::Config[:transaction_settings] = [{ extensions: ['ter'] }]
    AppOpticsAPM::Span.expects(:createHttpSpan).never

    get "/lobster"

    traces = get_all_traces
    assert traces.empty?
  end

  def test_transaction_settings_with_x_trace
    AppOpticsAPM::Config[:transaction_settings] = [{ extensions: ['ter'] }]
    AppOpticsAPM::Span.expects(:createHttpSpan).never

    xtrace = '2BE176BC800FE533EB7910F59C44F173BBF6ED7E07EFAAC4BEBB329CA801'
    res = get "/lobster", {}, { 'HTTP_X_TRACE' => xtrace }

    assert_equal xtrace, res.get_header('X-Trace')
    traces = get_all_traces
    assert traces.empty?

    refute AppOpticsAPM::Context.isValid
  end
end

