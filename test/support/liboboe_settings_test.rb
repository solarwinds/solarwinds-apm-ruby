# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'set'
require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'appoptics_apm/inst/rack'

unless defined?(JRUBY_VERSION)
  AppOpticsAPM::Config[:tracing_mode] = 'always'
  AppOpticsAPM::Config[:sample_rate] = 1e6

  class RackTestApp < Minitest::Test
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

    def test_localset_sample_source
      # skip("FIXME: broken on travis only") if ENV['TRAVIS'] == "true"

      # We make an initial call here which will force the appoptics_apm gem to retrieve
      # the sample_rate and sample_source from liboboe (via sample? method)
      get "/lobster"

      clear_all_traces

      get "/lobster"

      traces = get_all_traces
      traces.count.must_equal 3

      validate_outer_layers(traces, 'rack')

      kvs = {}
      kvs["SampleRate"] = 1000000
      kvs["SampleSource"] = 1 # (OBOE_SAMPLE_RATE_SOURCE_FILE)
      validate_event_keys(traces[0], kvs)
    end

    # Test logging of all Ruby datatypes against the SWIG wrapper
    # of addInfo which only has four overloads.
    # TODO these should probably have 'refute_raises' blocks around the 'log' calls
    def test_swig_datatypes_conversion
      event = AppOpticsAPM::Context.createEvent
      report_kvs = {}

      # Array
      report_kvs[:TestData] = [0, 1, 2, 5, 7.0]
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # Class
      report_kvs[:TestData] = AppOpticsAPM::Reporter
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # FalseClass
      report_kvs[:TestData] = false
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # Fixnum
      report_kvs[:TestData] = 1_873_293_293
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # Float
      report_kvs[:TestData] = 1.0001
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # Hash
      report_kvs[:TestData] = Hash.new
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # Integer
      report_kvs[:TestData] = 1
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # Module
      report_kvs[:TestData] = AppOpticsAPM
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # NilClass
      report_kvs[:TestData] = nil
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # Set
      report_kvs[:TestData] = Set.new(1..10)
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # String
      report_kvs[:TestData] = 'test value'
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # Symbol
      report_kvs[:TestData] = :TestValue
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)

      # TrueClass
      report_kvs[:TestData] = true
      AppOpticsAPM::API.log('test_layer', 'entry', report_kvs, event)
    end
  end
end
