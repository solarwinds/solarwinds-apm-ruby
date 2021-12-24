# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"
require 'mocha/minitest'

describe "Rails CRUD Tests" do

  before do
    AppOpticsAPM.config_lock.synchronize {
      @tm = AppOpticsAPM::Config[:tracing_mode]
      @sample_rate = AppOpticsAPM::Config[:sample_rate]
      @sanitize = AppOpticsAPM::Config[:sanitize_sql]
      @ac_backtrace = AppOpticsAPM::Config[:action_controller][:collect_backtraces]
      @ar_backtrace = AppOpticsAPM::Config[:active_record][:collect_backtraces]
      @rack_backtrace = AppOpticsAPM::Config[:rack][:collect_backtraces]
      @log_traceid = AppOpticsAPM::Config[:log_traceId]

      AppOpticsAPM::Config[:sanitize_sql] = false
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false
      AppOpticsAPM::Config[:active_record][:collect_backtraces] = false
      AppOpticsAPM::Config[:rack][:collect_backtraces] = false
      AppOpticsAPM::Config[:log_traceId] = :always
    }

    @log_traceid_regex = /\/\*\s*trace-id:\s*[0-9a-f]{32}\s*\*\/\s*/
    clear_query_log
  end

  after do
    AppOpticsAPM.config_lock.synchronize {
      AppOpticsAPM::Config[:tracing_mode] = @tm
      AppOpticsAPM::Config[:sample_rate] = @sample_rate
      AppOpticsAPM::Config[:sanitize_sql] = @sanitize
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = @ac_backtrace
      AppOpticsAPM::Config[:active_record][:collect_backtraces] = @ar_backtrace
      AppOpticsAPM::Config[:rack][:collect_backtraces] = @rack_backtrace
      AppOpticsAPM::Config[:log_traceId] = @log_traceid
    }

    clear_all_traces
    clear_query_log
  end

  it "should trace CREATE correctly" do
    skip if defined?(JRUBY_VERSION)

    clear_all_traces

    response = create_widget
    _(response.code).must_equal '200'

    traces = get_all_traces

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 0

    ar_traces = traces.select { |trace| trace['Layer'] == 'activerecord' }
    _(ar_traces.find { |trace| trace.has_key?('RemoteHost') }).wont_be_nil 'RemoteHost key is missing'

    ar_traces.select! { |trace| trace['Label'] == 'entry' }
    if Rails::VERSION::STRING < '5'  && ENV['DBTYPE'] == 'mysql'
      _(ar_traces.count).must_equal 3 # mysql + older rails add a BEGIN and a COMMIT query
    else
      _(ar_traces.count).must_equal 1
    end

    _(traces.select { |trace| trace['Query'] =~ /INSERT/ }.count).must_equal 2

    assert query_logged?(/#{@log_traceid_regex}\s*INSERT/), "Logged query didn't match what we're looking for"
  end

  it "should trace READ correctly" do
    skip if defined?(JRUBY_VERSION)

    widget = JSON.parse(create_widget.body)

    clear_all_traces
    response = read_widget(widget)
    _(response.code).must_equal '200'

    traces = get_all_traces

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    _(traces.count).must_equal 1
    _(traces[0]['Query']).must_match /SELECT/

    assert query_logged?(/#{@log_traceid_regex}\s*INSERT/), "Logged query didn't match what we're looking for"
    assert query_logged?(/#{@log_traceid_regex}\s*SELECT/), "Logged query didn't match what we're looking for"
  end

  it "should trace UPDATE correctly" do
    skip if defined?(JRUBY_VERSION)

    widget = JSON.parse(create_widget.body)

    clear_all_traces
    widget['name'] = 'Sand'
    widget['description'] = 'the sandy dog'
    response = update_widget(widget)
    _(response.code).must_equal '200'

    traces = get_all_traces

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    if Rails::VERSION::STRING < '5' && ENV['DBTYPE'] == 'mysql'
      _(traces.count).must_equal 4 # mysql + older rails add a BEGIN and a COMMIT query
    else
      _(traces.count).must_equal 2
    end

    _(traces.select { |trace| trace['Query'] =~ /SELECT/ }.count).must_equal 1
    _(traces.select { |trace| trace['Query'] =~ /UPDATE/ }.count).must_equal 1

    assert query_logged?(/#{@log_traceid_regex}\s*INSERT/), "Logged query didn't match what we're looking for"
    assert query_logged?(/#{@log_traceid_regex}\s*SELECT/), "Logged query didn't match what we're looking for"
    assert query_logged?(/#{@log_traceid_regex}\s*UPDATE/), "Logged query didn't match what we're looking for"
  end

  it "should trace DELETE correctly" do
    skip if defined?(JRUBY_VERSION)

    widget = JSON.parse(create_widget.body)

    clear_all_traces
    response = destroy_widget(widget)
    _(response.code).must_equal '200'

    traces = get_all_traces

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    _(traces.count).must_equal 1
    _(traces[0]['Query']).must_match /DELETE/

    assert query_logged?(/#{@log_traceid_regex}\s*INSERT/), "Logged query didn't match what we're looking for"
    assert query_logged?(/#{@log_traceid_regex}\s*DELETE/), "Logged query didn't match what we're looking for"
  end
end

def create_widget
  uri = URI.parse("http://127.0.0.1:8140/widgets")
  header = { 'Content-Type' => 'application/json' }
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri, header)

  widget = { widget: { name: 'Bob', description: 'the bobby dog' } }
  request.body = widget.to_json
  http.request(request)
end

def read_widget(widget)
  uri = URI.parse("http://127.0.0.1:8140/widgets/#{widget['id']}")

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.request_uri)
  http.request(request)
end

def update_widget(widget)
  uri = URI.parse("http://127.0.0.1:8140/widgets/#{widget['id']}")
  header = { 'Content-Type' => 'application/json' }

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Put.new(uri.request_uri, header)
  request.body = { :widget => widget }.to_json
  http.request(request)
end

def destroy_widget(widget)
  uri = URI.parse("http://127.0.0.1:8140/widgets/#{widget['id']}")

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Delete.new(uri.request_uri)
  http.request(request)
end