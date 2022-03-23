# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.


require 'minitest_helper'
require 'solarwinds_apm/inst/rack'
require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

describe 'CurbTest' do # < Minitest::Test
  include Rack::Test::Methods

  before do
    clear_all_traces
    SolarWindsAPM.config_lock.synchronize {
      @cb = SolarWindsAPM::Config[:curb][:collect_backtraces]
      @log_args = SolarWindsAPM::Config[:curb][:log_args]
      @tm = SolarWindsAPM::Config[:tracing_mode]
    }
  end

  after do
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:curb][:collect_backtraces] = @cb
      SolarWindsAPM::Config[:curb][:log_args] = @log_args
      SolarWindsAPM::Config[:tracing_mode] = @tm
    }
  end

  def app
    SinatraSimple
  end

  def assert_correct_traces(url, method)
    traces = get_all_traces
    assert_equal 6, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal 'curb',                    traces[1]['Layer']
    assert_equal 'entry',                   traces[1]['Label']
    assert_equal 'rsc',                     traces[1]['Spec']
    assert_equal 1,                         traces[1]['IsService']
    # curb started using URI#to_s and may have a trailing '?', https://github.com/taf2/curb/commit/32fa6d78968c3b63e2a54a2c326efb577db04043
    assert_equal url,                       traces[1]['RemoteURL'].chomp('?')
    assert_equal method,                    traces[1]['HTTPMethod']

    assert_equal 'curb',                    traces[4]['Layer']
    assert_equal 'exit',                    traces[4]['Label']
    assert                                  traces[4]['Backtrace']
  end

  it 'reports version init' do
    init_kvs = ::SolarWindsAPM::Util.build_init_report
    assert init_kvs.key?('Ruby.curb.Version')
    assert_equal ::Curl::CURB_VERSION, init_kvs['Ruby.curb.Version']
  end

  it 'class_get_request' do
    response = nil

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      response = Curl.get('http://127.0.0.1:8101/')
    end

    assert response.body_str == "Hello SolarWindsAPM!"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    assert_correct_traces('http://127.0.0.1:8101/', 'GET')
  end

  it 'class delete request' do
    response = nil

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      response = Curl.delete('http://127.0.0.1:8101/?curb_delete_test', :id => 1)
    end

    assert response.body_str == "Hello SolarWindsAPM!"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    assert_correct_traces('http://127.0.0.1:8101/?curb_delete_test', 'DELETE')
  end

  it 'class post request' do
    response = nil

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      response = Curl.post('http://127.0.0.1:8101/')
    end

    assert response.body_str == "Hello SolarWindsAPM!"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    assert_correct_traces('http://127.0.0.1:8101/', 'POST')
  end

  it 'easy class perform' do
    response = nil

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      response = Curl::Easy.perform("http://127.0.0.1:8101/")
    end

    assert response.is_a?(::Curl::Easy)
    assert response.body_str == "Hello SolarWindsAPM!"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    assert_correct_traces('http://127.0.0.1:8101/', 'GET')
  end

  it 'easy http head' do
    c = nil

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      c = Curl::Easy.new("http://127.0.0.1:8101/")
      c.http_head
    end

    assert c.is_a?(::Curl::Easy), "Response type"
    assert c.response_code == 200
    assert c.header_str =~ /X-Trace/, "X-Trace response header"

    assert_correct_traces('http://127.0.0.1:8101/', 'GET')
  end

  it 'easy http put' do
    c = nil

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      c = Curl::Easy.new("http://127.0.0.1:8101/")
      c.http_put(:id => 1)
    end

    assert c.is_a?(::Curl::Easy), "Response type"
    assert c.response_code == 200
    assert c.header_str =~ /X-Trace/, "X-Trace response header"

    assert_correct_traces('http://127.0.0.1:8101/', 'PUT')
  end

  it 'easy http post' do
    c = nil

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      url = "http://127.0.0.1:8101/"
      c = Curl::Easy.new(url)
      c.http_post(url, :id => 1)
    end

    assert c.is_a?(::Curl::Easy), "Response type"
    assert c.response_code == 200
    assert c.header_str =~ /X-Trace/, "X-Trace response header"

    assert_correct_traces('http://127.0.0.1:8101/', 'POST')
  end

  it 'class_ etch with_ lock' do
    response = nil

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      response = Curl::Easy.perform("http://127.0.0.1:8101/") do |curl|
        curl.headers["User-Agent"] = "SolarWindsAPM 2000"
      end
    end

    assert response.is_a?(::Curl::Easy), "Response type"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    traces = get_all_traces
    assert_equal 6, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_correct_traces('http://127.0.0.1:8101/', 'GET')
  end

  it 'multi basic get' do
    responses = nil
    easy_options = { :follow_location => true }
    multi_options = { :pipeline => false }

    urls = []
    urls << "http://127.0.0.1:8101/?one=1"
    urls << "http://127.0.0.1:8101/?two=2"
    urls << "http://127.0.0.1:8101/?three=3"

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      Curl::Multi.get(urls, easy_options, multi_options) do |easy|
        nil
      end
    end

    traces = get_all_traces
    assert_equal 10, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal traces[1]['Layer'], 'curb_multi'
    assert_equal traces[1]['Label'], 'entry'
    assert_equal traces[8]['Layer'], 'curb_multi'
    assert_equal traces[8]['Label'], 'exit'
  end

  it 'multi basic post' do
    easy_options = { :follow_location => true, :multipart_form_post => true }
    multi_options = { :pipeline => true }

    urls = []
    urls << { :url => "http://127.0.0.1:8101/1", :post_fields => { :id => 1 } }
    urls << { :url => "http://127.0.0.1:8101/2", :post_fields => { :id => 2 } }
    urls << { :url => "http://127.0.0.1:8101/3", :post_fields => { :id => 3 } }

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      Curl::Multi.post(urls, easy_options, multi_options) do |easy|
        nil
      end
    end

    traces = get_all_traces
    assert_equal 10, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal traces[1]['Layer'], 'curb_multi'
    assert_equal traces[1]['Label'], 'entry'
    assert_equal traces[8]['Layer'], 'curb_multi'
    assert_equal traces[8]['Label'], 'exit'
  end

  it 'multi basic get pipeline' do
    easy_options = { :follow_location => true }
    multi_options = { :pipeline => true }

    urls = []
    urls << "http://127.0.0.1:8101/?one=1"
    urls << "http://127.0.0.1:8101/?two=2"
    urls << "http://127.0.0.1:8101/?three=3"

    SolarWindsAPM::SDK.start_trace('curb_tests') do
      Curl::Multi.get(urls, easy_options, multi_options) do |easy|
        nil
      end
    end

    traces = get_all_traces
    assert_equal 10, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal traces[1]['Layer'], 'curb_multi'
    assert_equal traces[1]['Label'], 'entry'
    assert_equal traces[8]['Layer'], 'curb_multi'
    assert_equal traces[8]['Label'], 'exit'
  end

  it 'multi advanced get' do
    responses = {}

    urls = []
    urls << "http://127.0.0.1:8101/?one=1"
    urls << "http://127.0.0.1:8101/?two=2"
    urls << "http://127.0.0.1:8101/?three=3"

    SolarWindsAPM::SDK.start_trace('curb_tests') do
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
    assert_equal 10, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal traces[1]['Layer'], 'curb_multi'
    assert_equal traces[1]['Label'], 'entry'
    assert_equal traces[8]['Layer'], 'curb_multi'
    assert_equal traces[8]['Label'], 'exit'
  end

  it 'requests with errors' do
    begin
      SolarWindsAPM::SDK.start_trace('curb_tests') do
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
    # curb started using URI#to_s and may have a trailing '?', https://github.com/taf2/curb/commit/32fa6d78968c3b63e2a54a2c326efb577db04043
    assert_equal 'http://asfjalkfjlajfljkaljf/',   traces[1]['RemoteURL'].chomp('?')
    assert_equal 'GET',                            traces[1]['HTTPMethod']

    assert_equal 'curb',                           traces[2]['Layer']
    assert_equal 'error',                          traces[2]['Spec']
    assert_equal 'error',                          traces[2]['Label']
    assert_equal "Curl::Err::HostResolutionError", traces[2]['ErrorClass']
    assert                                         traces[2].key?('ErrorMsg')
    assert                                         traces[2].key?('Backtrace')
    assert_equal 1, traces.select { |trace| trace['Label'] == 'error' }.count

    assert_equal 'curb',                           traces[3]['Layer']
    assert_equal 'exit',                           traces[3]['Label']
    assert                                         traces[3]['Backtrace']
  end

  it 'obey log args when false' do
    # When testing global config options, use the config_lock
    # semaphore to lock between other running tests.
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:curb][:log_args] = false

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        Curl.get('http://127.0.0.1:8101/?blah=1')
      end
    }

    traces = get_all_traces
    assert_equal 6, traces.count, "Trace count"
    assert_equal "http://127.0.0.1:8101/",         traces[1]['RemoteURL']
  end

  it 'obey log args when true' do
    # When testing global config options, use the config_lock
    # semaphore to lock between other running tests.
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:curb][:log_args] = true

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        Curl.get('http://127.0.0.1:8101/?blah=1')
      end
    }

    traces = get_all_traces
    assert_equal 6, traces.count, "Trace count"
    assert_match "http://127.0.0.1:8101/?blah=1", traces[1]['RemoteURL']
  end

  it 'without tracing class get' do
    response = Curl.get('http://127.0.0.1:8101/?blah=1')

    assert response.headers['X-Trace'] == nil
    assert response.body_str == "Hello SolarWindsAPM!"
    assert response.response_code == 200
  end

  it 'without tracing easy perform' do
    response = Curl::Easy.perform("http://127.0.0.1:8101/")

    assert response.headers['X-Trace'] == nil
    assert response.body_str == "Hello SolarWindsAPM!"
    assert response.response_code == 200
  end

  it 'obey collect backtraces when true' do
    # When testing global config options, use the config_lock
    # semaphore to lock between other running tests.
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:curb][:collect_backtraces] = true
      sleep 1

      SolarWindsAPM::SDK.start_trace('curb_test') do
        Curl.get("http://127.0.0.1:8101/")
      end
    }

    traces = get_all_traces
    assert traces.find { |tr| tr['Layer'] == 'curb' && tr['Label'] == 'exit' }['Backtrace']
  end

  it 'obey collect backtraces when false' do
    # When testing global config options, use the config_lock
    # semaphore to lock between other running tests.
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:curb][:collect_backtraces] = false

      SolarWindsAPM::SDK.start_trace('curb_test') do
        Curl.get("http://127.0.0.1:8101/")
      end
    }

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'curb', 'Backtrace')
  end

end
