require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'oboe/inst/rack'

class RackTestApp < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use Oboe::Rack
      map "/lobster" do
        use Rack::Lint
        run Rack::Lobster.new
      end
    }
  end

  def test_custom_do_not_trace
    clear_all_traces

    dnt_original = Oboe::Config[:dnt_regexp]
    Oboe::Config[:dnt_regexp] = "lobster$"

    get "/lobster"

    traces = get_all_traces
    assert traces.empty?

    Oboe::Config[:dnt_regexp] = dnt_original
  end

  def test_do_not_trace_static_assets
    clear_all_traces

    get "/assets/static_asset.png"

    traces = get_all_traces
    assert traces.empty?

    assert last_response.status == 404
  end
end

