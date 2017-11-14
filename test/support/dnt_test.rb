# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'appoptics/inst/rack'

class RackTestApp < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use AppOptics::Rack
      map "/lobster" do
        use Rack::Lint
        run Rack::Lobster.new
      end
    }
  end

  def test_custom_do_not_trace
    clear_all_traces

    dnt_original = AppOptics::Config[:dnt_regexp]
    AppOptics::Config[:dnt_regexp] = "lobster$"

    get "/lobster"

    traces = get_all_traces
    assert traces.empty?

    AppOptics::Config[:dnt_regexp] = dnt_original
  end

  def test_do_not_trace_static_assets
    clear_all_traces

    get "/assets/static_asset.png"

    traces = get_all_traces
    assert traces.empty?

    assert last_response.status == 404
  end

  def test_complex_do_not_trace
    skip "not supported" if RUBY_VERSION < '1.9'

    clear_all_traces

    dnt_original = AppOptics::Config[:dnt_regexp]

    # Do not trace .js files _except for_ show.js
    AppOptics::Config[:dnt_regexp] = "(\.js$)(?<!show.js)"

    # First: We shouldn't trace general .js files
    get "/javascripts/application.js"

    traces = get_all_traces
    assert traces.empty?

    # Second: We should trace show.js
    clear_all_traces

    get "/javascripts/show.js"

    traces = get_all_traces
    assert !traces.empty?

    AppOptics::Config[:dnt_regexp] = dnt_original
  end
end

