# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'mocha/mini_test'

  class TyphoeusMockedTest < Minitest::Test

    def setup
      TraceView.config_lock.synchronize do
        @sample_rate = TraceView::Config[:sample_rate]
      end
    end

    def teardown
      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = @sample_rate
        TraceView::Config[:blacklist] = []
      end
    end

    ############# Typhoeus::Request ##############################################

    def test_tracing_sampling
      TraceView::API.start_trace('typhoeus_tests') do
        request = Typhoeus::Request.new("http://127.0.0.2:8101/", {:method=>:get})
        request.run

        assert request.options[:headers]['X-Trace']
        assert_match /^2B[0-9,A-F]*01$/,request.options[:headers]['X-Trace']
      end
    end

    def test_tracing_not_sampling
      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = 0
        TraceView::API.start_trace('typhoeus_tests') do
          request = Typhoeus::Request.new("http://127.0.0.1:8101/", {:method=>:get})
          request.run

          assert request.options[:headers]['X-Trace']
          assert_match /^2B[0-9,A-F]*00$/, request.options[:headers]['X-Trace']
          refute_match /^2B0*$/, request.options[:headers]['X-Trace']
        end
      end
    end

    def test_no_xtrace
      request = Typhoeus::Request.new("http://127.0.0.1:8101/", {:method=>:get})
      request.run

      refute request.options[:headers]['X-Trace']
    end

    def test_blacklisted
      TraceView.config_lock.synchronize do
        TraceView::Config.blacklist << '127.0.0.1'
        TraceView::API.start_trace('typhoeus_tests') do
          request = Typhoeus::Request.new("http://127.0.0.1:8101/", {:method=>:get})
          request.run

          refute request.options[:headers]['X-Trace']
        end
      end
    end

    def test_not_sampling_blacklisted
      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = 0
        TraceView::Config.blacklist << '127.0.0.1'
        TraceView::API.start_trace('typhoeus_tests') do
          request = Typhoeus::Request.new("http://127.0.0.1:8101/", {:method=>:get})
          request.run

          refute request.options[:headers]['X-Trace']
        end
      end
    end


    ############# Typhoeus::Hydra ##############################################

    def test_hydra_tracing_sampling
      TraceView::API.start_trace('typhoeus_tests') do
        hydra = Typhoeus::Hydra.hydra
        request_1 = Typhoeus::Request.new("http://127.0.0.2:8101/", {:method=>:get})
        request_2 = Typhoeus::Request.new("http://127.0.0.2:8101/counting_sheep", {:method=>:get})
        hydra.queue(request_1)
        hydra.queue(request_2)
        hydra.run

        assert request_1.options[:headers]['X-Trace'], "There is an X-Trace header"
        assert_match /^2B[0-9,A-F]*01$/, request_1.options[:headers]['X-Trace']
        assert request_2.options[:headers]['X-Trace'], "There is an X-Trace header"
        assert_match /^2B[0-9,A-F]*01$/, request_2.options[:headers]['X-Trace']
      end
    end

    def test_hydra_tracing_not_sampling
      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = 0
        TraceView::API.start_trace('typhoeus_tests') do
          hydra = Typhoeus::Hydra.hydra
          request_1 = Typhoeus::Request.new("http://127.0.0.2:8101/", {:method=>:get})
          request_2 = Typhoeus::Request.new("http://127.0.0.2:8101/counting_sheep", {:method=>:get})
          hydra.queue(request_1)
          hydra.queue(request_2)
          hydra.run

          assert request_1.options[:headers]['X-Trace'], "There is an X-Trace header"
          assert_match /^2B[0-9,A-F]*00$/, request_1.options[:headers]['X-Trace']
          refute_match /^2B0*$/, request_1.options[:headers]['X-Trace']
          assert request_2.options[:headers]['X-Trace'], "There is an X-Trace header"
          assert_match /^2B[0-9,A-F]*00$/, request_2.options[:headers]['X-Trace']
          refute_match /^2B0*$/, request_2.options[:headers]['X-Trace']
        end
      end
    end

    def test_no_xtrace
      hydra = Typhoeus::Hydra.hydra
      request_1 = Typhoeus::Request.new("http://127.0.0.2:8101/", {:method=>:get})
      request_2 = Typhoeus::Request.new("http://127.0.0.2:8101/counting_sheep", {:method=>:get})
      hydra.queue(request_1)
      hydra.queue(request_2)
      hydra.run

      refute request_1.options[:headers]['X-Trace'], "There should not be an X-Trace header"
      refute request_2.options[:headers]['X-Trace'], "There should not be an X-Trace header"
    end

    def test_blacklisted
      TraceView.config_lock.synchronize do
        TraceView::Config.blacklist << '127.0.0.2'
        TraceView::API.start_trace('typhoeus_tests') do
          hydra = Typhoeus::Hydra.hydra
          request_1 = Typhoeus::Request.new("http://127.0.0.2:8101/", {:method=>:get})
          request_2 = Typhoeus::Request.new("http://127.0.0.2:8101/counting_sheep", {:method=>:get})
          hydra.queue(request_1)
          hydra.queue(request_2)
          hydra.run

          refute request_1.options[:headers]['X-Trace'], "There should not be an X-Trace header"
          refute request_2.options[:headers]['X-Trace'], "There should not be an X-Trace header"
        end
      end
    end

    def test_not_sampling_blacklisted
      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = 0
        TraceView::Config.blacklist << '127.0.0.2'
        TraceView::API.start_trace('typhoeus_tests') do
          hydra = Typhoeus::Hydra.hydra
          request_1 = Typhoeus::Request.new("http://127.0.0.2:8101/", {:method=>:get})
          request_2 = Typhoeus::Request.new("http://127.0.0.2:8101/counting_sheep", {:method=>:get})
          hydra.queue(request_1)
          hydra.queue(request_2)
          hydra.run

          refute request_1.options[:headers]['X-Trace'], "There should not be an X-Trace header"
          refute request_2.options[:headers]['X-Trace'], "There should not be an X-Trace header"
        end
      end
    end

  end
end
