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

      AppOpticsAPM::Config[:sanitize_sql] = false
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false
      AppOpticsAPM::Config[:active_record][:collect_backtraces] = false
      AppOpticsAPM::Config[:rack][:collect_backtraces] = false
    }
  end

  after do
    AppOpticsAPM.config_lock.synchronize {
      AppOpticsAPM::Config[:tracing_mode] = @tm
      AppOpticsAPM::Config[:sample_rate] = @sample_rate
      AppOpticsAPM::Config[:sanitize_sql] = @sanitize
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = @ac_backtrace
      AppOpticsAPM::Config[:active_record][:collect_backtraces] = @ar_backtrace
      AppOpticsAPM::Config[:rack][:collect_backtraces] = @rack_backtrace
    }
  end

  it "should trace CREATE correctly" do
    skip if defined?(JRUBY_VERSION)

    clear_all_traces

    response = create_widget
    response.code.must_equal '200'

    traces = get_all_traces

    traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    if Rails::VERSION::STRING < '5'  && ENV['DBTYPE'] == 'mysql'
      traces.count.must_equal 3 # mysql + older rails add a BEGIN and a COMMIT query
    else
      traces.count.must_equal 1
    end

    traces.select { |trace| trace['Query'] =~ /^INSERT/ }.count.must_equal 1
  end

  it "should trace READ correctly" do
    skip if defined?(JRUBY_VERSION)

    widget = JSON.parse(create_widget.body)

    clear_all_traces
    response = read_widget(widget)
    response.code.must_equal '200'

    traces = get_all_traces

    traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    traces.count.must_equal 1
    traces[0]['Query'].must_match /^SELECT/
  end

  it "should trace UPDATE correctly" do
    skip if defined?(JRUBY_VERSION)

    widget = JSON.parse(create_widget.body)

    clear_all_traces
    widget['name'] = 'Sand'
    widget['description'] = 'the sandy dog'
    response = update_widget(widget)
    response.code.must_equal '200'

    traces = get_all_traces

    traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    if Rails::VERSION::STRING < '5' && ENV['DBTYPE'] == 'mysql'
      traces.count.must_equal 4 # mysql + older rails add a BEGIN and a COMMIT query
    else
      traces.count.must_equal 2
    end

    traces.select { |trace| trace['Query'] =~ /^SELECT/ }.count.must_equal 1
    traces.select { |trace| trace['Query'] =~ /^UPDATE/ }.count.must_equal 1
  end

  it "should trace DELETE correctly" do
    skip if defined?(JRUBY_VERSION)

    widget = JSON.parse(create_widget.body)

    clear_all_traces
    response = destroy_widget(widget)
    response.code.must_equal '200'

    traces = get_all_traces

    traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 0

    traces.select! { |trace| trace['Label'] == 'entry' && trace['Layer'] == 'activerecord' }
    traces.count.must_equal 1
    traces[0]['Query'].must_match /^DELETE/
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