# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'appoptics/inst/rack'
require 'net/http'

class NoopTest < Minitest::Test
  include Rack::Test::Methods

  class ArrayTest < Array; end

  def setup
    AppOptics.loaded = false
  end

  def teardown
    AppOptics.loaded = true
  end

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

  def test_requests_still_work
    clear_all_traces

    get "/lobster"

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_tracing_api_doesnt_barf
    AppOptics::API.start_trace('noop_test')  do
      AppOptics::API.trace('blah_block') do
        "this block should not be traced"
      end
    end

    AppOptics::API.log_start('noop_test')
    AppOptics::API.log_info(nil, {:ok => :yeah })
    AppOptics::API.log_exception(nil, Exception.new("yeah ok"))
    AppOptics::API.log_end('noop_test')

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_method_profiling_doesnt_barf
    AppOptics::API.profile_method(ArrayTest, :sort)

    x = ArrayTest.new
    x.push(1).push(3).push(2)
    assert_equal [1, 2, 3], x.sort
  end

  def test_appoptics_config_doesnt_barf
    tm = AppOptics::Config[:tracing_mode]
    vb = AppOptics::Config[:verbose]
    la = AppOptics::Config[:rack][:log_args]

    # Test that we can set various things into AppOptics::Config still
    AppOptics::Config[:tracing_mode] = :always
    AppOptics::Config[:verbose] = false
    AppOptics::Config[:rack][:log_args] = true

    assert_equal :always,  AppOptics::Config[:tracing_mode]
    assert_equal false,    AppOptics::Config[:verbose]
    assert_equal true,     AppOptics::Config[:rack][:log_args]

    # Restore the originals
    AppOptics::Config[:tracing_mode] = tm
    AppOptics::Config[:verbose] = vb
    AppOptics::Config[:rack][:log_args] = la
  end
end

