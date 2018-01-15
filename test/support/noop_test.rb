# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'appoptics_apm/inst/rack'
require 'net/http'

class NoopTest < Minitest::Test
  include Rack::Test::Methods

  class ArrayTest < Array; end

  def setup
    AppOpticsAPM.loaded = false
  end

  def teardown
    AppOpticsAPM.loaded = true
  end

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

  def test_requests_still_work
    clear_all_traces

    get "/lobster"

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_tracing_api_doesnt_barf
    AppOpticsAPM::API.start_trace('noop_test')  do
      AppOpticsAPM::API.trace('blah_block') do
        "this block should not be traced"
      end
    end

    AppOpticsAPM::API.log_start('noop_test')
    AppOpticsAPM::API.log_info(nil, {:ok => :yeah })
    AppOpticsAPM::API.log_exception(nil, Exception.new("yeah ok"))
    AppOpticsAPM::API.log_end('noop_test')

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_method_profiling_doesnt_barf
    AppOpticsAPM::API.profile_method(ArrayTest, :sort)

    x = ArrayTest.new
    x.push(1).push(3).push(2)
    assert_equal [1, 2, 3], x.sort
  end

  def test_appoptics_config_doesnt_barf
    tm = AppOpticsAPM::Config[:tracing_mode]
    vb = AppOpticsAPM::Config[:verbose]
    la = AppOpticsAPM::Config[:rack][:log_args]

    # Test that we can set various things into AppOpticsAPM::Config still
    AppOpticsAPM::Config[:tracing_mode] = :always
    AppOpticsAPM::Config[:verbose] = false
    AppOpticsAPM::Config[:rack][:log_args] = true

    assert_equal :always, AppOpticsAPM::Config[:tracing_mode]
    assert_equal false, AppOpticsAPM::Config[:verbose]
    assert_equal true, AppOpticsAPM::Config[:rack][:log_args]

    # Restore the originals
    AppOpticsAPM::Config[:tracing_mode] = tm
    AppOpticsAPM::Config[:verbose] = vb
    AppOpticsAPM::Config[:rack][:log_args] = la
  end
end

