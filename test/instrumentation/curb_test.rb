# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)

  require 'minitest_helper'
  require 'appoptics_apm/inst/rack'
  require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

  class CurbTest < Minitest::Test
    include Rack::Test::Methods

    def setup
      clear_all_traces
      AppOpticsAPM.config_lock.synchronize {
        @cb = AppOpticsAPM::Config[:curb][:collect_backtraces]
        @log_args = AppOpticsAPM::Config[:curb][:log_args]
        @tm = AppOpticsAPM::Config[:tracing_mode]
      }
    end

    def teardown
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:curb][:collect_backtraces] = @cb
        AppOpticsAPM::Config[:curb][:log_args] = @log_args
        AppOpticsAPM::Config[:tracing_mode] = @tm
      }
    end

    def app
      SinatraSimple
    end

    def assert_correct_traces(url, method)
      traces = get_all_traces
      assert_equal 7, traces.count, "Trace count"
      validate_outer_layers(traces, "curb_tests")

      assert_equal 'curb',                    traces[1]['Layer']
      assert_equal 'entry',                   traces[1]['Label']
      assert_equal 1,                         traces[1]['IsService']
      assert_equal url,                       traces[1]['RemoteURL']
      assert_equal method,                    traces[1]['HTTPMethod']
      assert                                  traces[1]['Backtrace']

      assert_equal 'curb',                    traces[5]['Layer']
      assert_equal 'exit',                    traces[5]['Label']
    end

    def test_reports_version_init
      init_kvs = ::AppOpticsAPM::Util.build_init_report
      assert init_kvs.key?('Ruby.curb.Version')
      assert_equal ::Curl::CURB_VERSION, init_kvs['Ruby.curb.Version']
    end

    def test_class_get_request
      response = nil

      AppOpticsAPM::API.start_trace('curb_tests') do
        response = Curl.get('http://127.0.0.1:8101/')
      end

      assert response.body_str == "Hello AppOpticsAPM!"
      assert response.response_code == 200
      assert response.header_str =~ /X-Trace/, "X-Trace response header"

      assert_correct_traces('http://127.0.0.1:8101/', 'GET')
    end

    def test_class_delete_request
      response = nil

      AppOpticsAPM::API.start_trace('curb_tests') do
        response = Curl.delete('http://127.0.0.1:8101/?curb_delete_test', :id => 1)
      end

      assert response.body_str == "Hello AppOpticsAPM!"
      assert response.response_code == 200
      assert response.header_str =~ /X-Trace/, "X-Trace response header"

      assert_correct_traces('http://127.0.0.1:8101/?curb_delete_test', 'DELETE')
    end

    def test_class_post_request
      response = nil

      AppOpticsAPM::API.start_trace('curb_tests') do
        response = Curl.post('http://127.0.0.1:8101/')
      end

      assert response.body_str == "Hello AppOpticsAPM!"
      assert response.response_code == 200
      assert response.header_str =~ /X-Trace/, "X-Trace response header"

      assert_correct_traces('http://127.0.0.1:8101/', 'POST')
    end

    def test_easy_class_perform
      response = nil

      AppOpticsAPM::API.start_trace('curb_tests') do
        response = Curl::Easy.perform("http://127.0.0.1:8101/")
      end

      assert response.is_a?(::Curl::Easy)
      assert response.body_str == "Hello AppOpticsAPM!"
      assert response.response_code == 200
      assert response.header_str =~ /X-Trace/, "X-Trace response header"

      assert_correct_traces('http://127.0.0.1:8101/', 'GET')
    end

    def test_easy_http_head
      c = nil

      AppOpticsAPM::API.start_trace('curb_tests') do
        c = Curl::Easy.new("http://127.0.0.1:8101/")
        c.http_head
      end

      assert c.is_a?(::Curl::Easy), "Response type"
      assert c.response_code == 200
      assert c.header_str =~ /X-Trace/, "X-Trace response header"

      assert_correct_traces('http://127.0.0.1:8101/', 'GET')
    end

    def test_easy_http_put
      c = nil

      AppOpticsAPM::API.start_trace('curb_tests') do
        c = Curl::Easy.new("http://127.0.0.1:8101/")
        c.http_put(:id => 1)
      end

      assert c.is_a?(::Curl::Easy), "Response type"
      assert c.response_code == 200
      assert c.header_str =~ /X-Trace/, "X-Trace response header"

      assert_correct_traces('http://127.0.0.1:8101/', 'PUT')
    end

    def test_easy_http_post
      c = nil

      AppOpticsAPM::API.start_trace('curb_tests') do
        url = "http://127.0.0.1:8101/"
        c = Curl::Easy.new(url)
        c.http_post(url, :id => 1)
      end

      assert c.is_a?(::Curl::Easy), "Response type"
      assert c.response_code == 200
      assert c.header_str =~ /X-Trace/, "X-Trace response header"

      assert_correct_traces('http://127.0.0.1:8101/', 'POST')
    end

    def test_class_fetch_with_block
      response = nil

      AppOpticsAPM::API.start_trace('curb_tests') do
        response = Curl::Easy.perform("http://127.0.0.1:8101/") do |curl|
          curl.headers["User-Agent"] = "AppOpticsAPM 2000"
        end
      end

      assert response.is_a?(::Curl::Easy), "Response type"
      assert response.response_code == 200
      assert response.header_str =~ /X-Trace/, "X-Trace response header"

      traces = get_all_traces
      assert_equal 7, traces.count, "Trace count"
      validate_outer_layers(traces, "curb_tests")

      assert_correct_traces('http://127.0.0.1:8101/', 'GET')
    end

    def test_multi_basic_get
      responses = nil
      easy_options = {:follow_location => true}
      multi_options = {:pipeline => false}

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      AppOpticsAPM::API.start_trace('curb_tests') do
        responses = Curl::Multi.get(urls, easy_options, multi_options) do |easy|
          nil
        end
      end

      traces = get_all_traces
      assert_equal 13, traces.count, "Trace count"
      validate_outer_layers(traces, "curb_tests")

      assert_equal traces[1]['Layer'], 'curb_multi'
      assert_equal traces[1]['Label'], 'entry'
      assert_equal traces[11]['Layer'], 'curb_multi'
      assert_equal traces[11]['Label'], 'exit'
    end

    def test_multi_basic_post
      easy_options = {:follow_location => true, :multipart_form_post => true}
      multi_options = {:pipeline => true}

      urls = []
      urls << { :url => "http://127.0.0.1:8101/1", :post_fields => { :id => 1 } }
      urls << { :url => "http://127.0.0.1:8101/2", :post_fields => { :id => 2 } }
      urls << { :url => "http://127.0.0.1:8101/3", :post_fields => { :id => 3 } }

      AppOpticsAPM::API.start_trace('curb_tests') do
        Curl::Multi.post(urls, easy_options, multi_options) do |easy|
          nil
        end
      end

      traces = get_all_traces
      assert_equal 13, traces.count, "Trace count"
      validate_outer_layers(traces, "curb_tests")

      assert_equal traces[1]['Layer'], 'curb_multi'
      assert_equal traces[1]['Label'], 'entry'
      assert_equal traces[11]['Layer'], 'curb_multi'
      assert_equal traces[11]['Label'], 'exit'
    end

    def test_multi_basic_get_pipeline
      easy_options = {:follow_location => true}
      multi_options = {:pipeline => true}

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      AppOpticsAPM::API.start_trace('curb_tests') do
        Curl::Multi.get(urls, easy_options, multi_options) do |easy|
          nil
        end
      end

      traces = get_all_traces
      assert_equal 13, traces.count, "Trace count"
      validate_outer_layers(traces, "curb_tests")

      assert_equal traces[1]['Layer'], 'curb_multi'
      assert_equal traces[1]['Label'], 'entry'
      assert_equal traces[11]['Layer'], 'curb_multi'
      assert_equal traces[11]['Label'], 'exit'
    end

    def test_multi_advanced_get
      responses = {}

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      AppOpticsAPM::API.start_trace('curb_tests') do
        m = Curl::Multi.new
        urls.each do |url|
          responses[url] = ""
          c = Curl::Easy.new(url) do |curl|
            curl.follow_location = true
          end
          m.add c
        end

        m.perform do
          nil
        end
      end

      traces = get_all_traces
      assert_equal 13, traces.count, "Trace count"
      validate_outer_layers(traces, "curb_tests")

      assert_equal traces[1]['Layer'], 'curb_multi'
      assert_equal traces[1]['Label'], 'entry'
      assert_equal traces[11]['Layer'], 'curb_multi'
      assert_equal traces[11]['Label'], 'exit'
    end

    def test_requests_with_errors
      begin
        AppOpticsAPM::API.start_trace('curb_tests') do
          Curl.get('http://asfjalkfjlajfljkaljf/')
        end
      rescue
        # ignore exception, only check traces
      end

      traces = get_all_traces
      assert_equal 5, traces.count, "Trace count"
      validate_outer_layers(traces, "curb_tests")
      assert valid_edges?(traces), "Trace edge validation"

      assert_equal 1,                                traces[1]['IsService']
      assert_equal 'http://asfjalkfjlajfljkaljf/',   traces[1]['RemoteURL']
      assert_equal 'GET',                            traces[1]['HTTPMethod']
      assert                                         traces[1]['Backtrace']

      assert_equal 'curb',                           traces[2]['Layer']
      assert_equal 'error',                          traces[2]['Label']
      assert_equal "Curl::Err::HostResolutionError", traces[2]['ErrorClass']
      assert                                         traces[2].key?('ErrorMsg')
      assert                                         traces[2].key?('Backtrace')

      assert_equal 'curb',                           traces[3]['Layer']
      assert_equal 'exit',                           traces[3]['Label']
    end

    def test_obey_log_args_when_false
      # When testing global config options, use the config_lock
      # semaphore to lock between other running tests.
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:curb][:log_args] = false

        AppOpticsAPM::API.start_trace('curb_tests') do
          Curl.get('http://127.0.0.1:8101/?blah=1')
        end
      }

      traces = get_all_traces
      assert_equal 7, traces.count, "Trace count"
      assert_equal "http://127.0.0.1:8101/",         traces[1]['RemoteURL']
    end

    def test_obey_log_args_when_true
      # When testing global config options, use the config_lock
      # semaphore to lock between other running tests.
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:curb][:log_args] = true

        AppOpticsAPM::API.start_trace('curb_tests') do
          Curl.get('http://127.0.0.1:8101/?blah=1')
        end
      }

      traces = get_all_traces
      assert_equal 7, traces.count, "Trace count"
      assert_equal "http://127.0.0.1:8101/?blah=1", traces[1]['RemoteURL']
    end

    def test_without_tracing_class_get
      response = ::Curl.get('http://127.0.0.1:8101/?blah=1')

      assert response.headers['X-Trace'] == nil
      assert response.body_str == "Hello AppOpticsAPM!"
      assert response.response_code == 200
    end

    def test_without_tracing_easy_perform
      response = Curl::Easy.perform("http://127.0.0.1:8101/")

      assert response.headers['X-Trace'] == nil
      assert response.body_str == "Hello AppOpticsAPM!"
      assert response.response_code == 200
    end

    def test_obey_collect_backtraces_when_true
      # When testing global config options, use the config_lock
      # semaphore to lock between other running tests.
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:curb][:collect_backtraces] = true
        sleep 1

        AppOpticsAPM::API.start_trace('curb_test') do
          Curl.get("http://127.0.0.1:8101/")
        end
      }

      traces = get_all_traces
      layer_has_key(traces, 'curb', 'Backtrace')
    end

    def test_obey_collect_backtraces_when_false
      # When testing global config options, use the config_lock
      # semaphore to lock between other running tests.
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:curb][:collect_backtraces] = false

        AppOpticsAPM::API.start_trace('curb_test') do
          Curl.get("http://127.0.0.1:8101/")
        end
      }

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'curb', 'Backtrace')
    end

  end
end

