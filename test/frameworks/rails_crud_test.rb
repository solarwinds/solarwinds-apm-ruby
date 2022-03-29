# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"
require 'mocha/minitest'

describe "Rails CRUD Tests" do

  before do
    SolarWindsAPM.config_lock.synchronize {
      @tm = SolarWindsAPM::Config[:tracing_mode]
      @sample_rate = SolarWindsAPM::Config[:sample_rate]
      @sanitize = SolarWindsAPM::Config[:sanitize_sql]
      @ac_backtrace = SolarWindsAPM::Config[:action_controller][:collect_backtraces]
      @ar_backtrace = SolarWindsAPM::Config[:active_record][:collect_backtraces]
      @rack_backtrace = SolarWindsAPM::Config[:rack][:collect_backtraces]
      @log_traceid = SolarWindsAPM::Config[:log_traceId]
      @tag_sql = SolarWindsAPM::Config[:tag_sql]

      SolarWindsAPM::Config[:sanitize_sql] = false
      SolarWindsAPM::Config[:action_controller][:collect_backtraces] = false
      SolarWindsAPM::Config[:active_record][:collect_backtraces] = false
      SolarWindsAPM::Config[:rack][:collect_backtraces] = false
      SolarWindsAPM::Config[:log_traceId] = :never
    }

    @widget = JSON.parse(create_widget.body)

    @log_traceid_regex = /\/\*traceparent='[0-9a-f-]{55}'\*\//.freeze
    clear_all_traces
    clear_query_log
    SolarWindsAPM::Config[:tag_sql] = true
  end

  after do
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:tracing_mode] = @tm
      SolarWindsAPM::Config[:sample_rate] = @sample_rate
      SolarWindsAPM::Config[:sanitize_sql] = @sanitize
      SolarWindsAPM::Config[:action_controller][:collect_backtraces] = @ac_backtrace
      SolarWindsAPM::Config[:active_record][:collect_backtraces] = @ar_backtrace
      SolarWindsAPM::Config[:rack][:collect_backtraces] = @rack_backtrace
      SolarWindsAPM::Config[:log_traceId] = @log_traceid
      SolarWindsAPM::Config[:tag_sql] = @tag_sql
    }
  end

  it "should trace CREATE correctly" do
    response = create_widget
    _(response.code).must_equal '200'

    traces = get_all_traces

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 0

    ar_traces = traces.select { |trace| trace['Layer'] == 'activerecord' }
    _(ar_traces.find { |trace| trace.has_key?('RemoteHost') }).wont_be_nil 'RemoteHost key is missing'

    ar_traces.select! { |trace| trace['Label'] == 'entry' }
    _(ar_traces.count).must_equal 1

    _(traces.select { |trace| trace['Query'] =~ /INSERT/ }.count).must_equal 2

    assert query_logged?(/#{@log_traceid_regex}INSERT/), "Logged query didn't match what we're looking for"
  end

  it "should trace READ correctly" do
    response = read_widget(@widget)
    _(response.code).must_equal '200'

    traces = get_all_traces

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    _(traces.count).must_equal 1
    _(traces[0]['Query']).must_match /SELECT/

    # assert query_logged?(/#{@log_traceid_regex}INSERT/), "Logged query didn't match what we're looking for"
    assert query_logged?(/#{@log_traceid_regex}SELECT/), "Logged query didn't match what we're looking for"
  end

  it "should trace UPDATE correctly" do
    @widget['name'] = 'Sand'
    @widget['description'] = 'the sandy dog'
    response = update_widget(@widget)
    _(response.code).must_equal '200'

    traces = get_all_traces

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    _(traces.count).must_equal 2

    _(traces.select { |trace| trace['Query'] =~ /SELECT/ }.count).must_equal 1
    _(traces.select { |trace| trace['Query'] =~ /UPDATE/ }.count).must_equal 1

    assert query_logged?(/#{@log_traceid_regex}SELECT/), "Logged query didn't match what we're looking for"
    assert query_logged?(/#{@log_traceid_regex}UPDATE/), "Logged query didn't match what we're looking for"
  end

  it "should trace DELETE correctly" do
    response = destroy_widget(@widget)
    _(response.code).must_equal '200'

    traces = get_all_traces

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    _(traces.count).must_equal 1
    _(traces[0]['Query']).must_match /DELETE/

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