# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"
require 'mocha/minitest'
require 'fileutils'

require_relative '../jobs/sidekiq/activejob_worker_job'
require_relative '../servers/sidekiq_activejob.rb'

Sidekiq.configure_server do |config|
  config.redis = { :password => ENV['REDIS_PASSWORD'] || 'secret_pass' }
  if ENV.key?('REDIS_HOST')
    config.redis << { :url => "redis://#{ENV['REDIS_HOST']}:6379" }
  end
end

describe "RailsSharedTests" do
  # in alpine copy /usr/bin/wkhtmltopdf to the wkhtmltopdf-binary dir
  # doing it here because it can't be done before the wkhtmltopdf gem is installed
  @skip_wicked = false
  if File.exist?('/etc/alpine-release') && File.exist?('/usr/bin/wkhtmltopdf')
    ruby_version_min = RUBY_VERSION.gsub(/\.\d+$/, ".0")
    wk_fullname = Gem.loaded_specs["wkhtmltopdf-binary"].full_name
    alpine_version = File.open('/etc/alpine-release') { |f| f.readline }.strip
    bin_path = "/root/.rbenv/versions/#{RUBY_VERSION}/lib/ruby/gems/#{ruby_version_min}/gems/#{wk_fullname}/bin/wkhtmltopdf_alpine_#{alpine_version}_amd64"
    unless File.exist?(bin_path)
      FileUtils.cp('/usr/bin/wkhtmltopdf', bin_path)
    end
  else
    @skip_wicked = true
  end

  before do
    clear_all_traces
    AppOpticsAPM.config_lock.synchronize {
      @tm = AppOpticsAPM::Config[:tracing_mode]
      @sample_rate = AppOpticsAPM::Config[:sample_rate]
      @dnt_regexp = AppOpticsAPM::Config[:dnt_regexp]
      @ac_bt = AppOpticsAPM::Config[:action_controller][:collect_backtraces]
      @av_bt = AppOpticsAPM::Config[:action_view][:collect_backtraces]
      @rack_bt = AppOpticsAPM::Config[:rack][:collect_backtraces]
    }
  end

  after do
    AppOpticsAPM.config_lock.synchronize {
      AppOpticsAPM::Config[:tracing_mode] = @tm
      AppOpticsAPM::Config[:sample_rate] = @sample_rate
      AppOpticsAPM::Config[:dnt_regexp] = @dnt_regexp
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = @ac_bt
      AppOpticsAPM::Config[:action_view][:collect_backtraces] = @av_bt
      AppOpticsAPM::Config[:rack][:collect_backtraces] = @rack_bt
    }
  end

  it "should NOT trace when tracing is set to :disabled" do
    AppOpticsAPM.config_lock.synchronize do
      AppOpticsAPM::Config[:tracing_mode] = :disabled
      uri = URI.parse('http://127.0.0.1:8140/hello/world')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces
      _(traces.count).must_equal 0
    end
  end

  it "should NOT trace when sample_rate is 0" do
    AppOpticsAPM.config_lock.synchronize do
      AppOpticsAPM::Config[:sample_rate] = 0
      uri = URI.parse('http://127.0.0.1:8140/hello/world')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces
      _(traces.count).must_equal 0
    end
  end

  it "should NOT trace when there is no context" do
    response_headers = HelloController.action("world").call(
      "REQUEST_METHOD" => "GET",
      "rack.input" => -> {}
    )[1]

    _(response_headers.key?('X-Trace')).must_equal false

    traces = get_all_traces
    _(traces.count).must_equal 0
  end

  it "should send inbound metrics" do
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil

    AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    uri = URI.parse('http://127.0.0.1:8140/hello/world')
    Net::HTTP.get_response(uri)

    assert_equal "HelloController.world", test_action
    assert_equal "http://127.0.0.1:8140/hello/world", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error

    assert_controller_action(test_action)
  end

  it "should NOT send inbound metrics when tracing_mode is :disabled" do
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    AppOpticsAPM.config_lock.synchronize do
      AppOpticsAPM::Config[:tracing_mode] = :disabled
      AppOpticsAPM::Span.expects(:createHttpSpan).never

      uri = URI.parse('http://127.0.0.1:8140/hello/world')
      Net::HTTP.get_response(uri)
    end
  end

  it "should send metrics for 500 errors" do
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil

    AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    uri = URI.parse('http://127.0.0.1:8140/hello/servererror')
    Net::HTTP.get_response(uri)

    assert_equal "HelloController.servererror", test_action
    assert_equal "http://127.0.0.1:8140/hello/servererror", test_url
    assert_equal 500, test_status
    assert_equal "GET", test_method
    assert_equal 1, test_error

    assert_controller_action(test_action)
  end

  it "should find the controller action for a route with a parameter" do
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil

    AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    uri = URI.parse('http://127.0.0.1:8140/hello/15/show')
    Net::HTTP.get_response(uri)

    assert_equal "HelloController.show", test_action
    assert_equal "http://127.0.0.1:8140/hello/15/show", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error

    assert_controller_action(test_action)
  end

  it "should find controller action in the metal stack" do
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil

    AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    uri = URI.parse('http://127.0.0.1:8140/hello/metal')
    r = Net::HTTP.get_response(uri)

    assert_equal 200, test_status
    assert_equal "FerroController.world", test_action
    assert_equal "http://127.0.0.1:8140/hello/metal", test_url
    assert_equal "GET", test_method
    assert_equal 0, test_error

    assert_controller_action(test_action)
  end

  it "should use wrapped class for ActiveJobs" do
    skip unless defined?(ActiveJob)
    AppOpticsAPM::SDK.start_trace('test_trace') do
      ActiveJobWorkerJob.perform_later
    end

    # Allow the job to be run
    sleep 5

    traces = get_all_traces

    sidekiq_traces = traces.select { |tr| tr['Layer'] =~ /sidekiq/ }
    assert_equal 4, sidekiq_traces.count, "count sidekiq traces"
    assert sidekiq_traces.find { |tr| tr['Layer'] == 'sidekiq-client' && tr['JobName'] == 'ActiveJobWorkerJob' }
    assert sidekiq_traces.find { |tr| tr['Layer'] == 'sidekiq-worker' && tr['JobName'] == 'ActiveJobWorkerJob' }
    assert sidekiq_traces.find { |tr| tr['Layer'] == 'sidekiq-worker' && tr['Action'] == 'ActiveJobWorkerJob' }

  end

  ### wicked_pdf gem ###########################################################
  # we don't instrument wicked_pdf, but its instrumentation can
  # interfere with our instrumentation

  it "finds a 'wicked_pdf.register' initializer" do
    found = Rails.application.initializers.any? do |initializer|
      initializer.name == 'wicked_pdf.register'
    end

    assert found, "'wicked_pdf.register' initializer not found, maybe it changed name"
  end

  it "traces html from the 'wicked' controller" do
    AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false
    AppOpticsAPM::Config[:action_view][:collect_backtraces] = false
    AppOpticsAPM::Config[:rack][:collect_backtraces] = false
    uri = URI.parse('http://127.0.0.1:8140/wicked')
    r = Net::HTTP.get_response(uri)

    traces = get_all_traces

    assert_equal 6, traces.count
    valid_edges?(traces)
    assert_equal 2, traces.select { |tr| tr['Layer'] =~ /actionview/ }.count
  end

  it "traces pdfs from the 'wicked' controller" do
    skip if @skip_wicked
    # fyi: wicked_pdf is not instrumented
    AppOpticsAPM::Config[:dnt_regexp] = ''
    AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false
    AppOpticsAPM::Config[:action_view][:collect_backtraces] = false
    AppOpticsAPM::Config[:rack][:collect_backtraces] = false

    uri = URI.parse('http://127.0.0.1:8140/wicked.pdf')
    r = Net::HTTP.get_response(uri)

    traces = get_all_traces
    assert_equal 6, traces.count
    valid_edges?(traces)

    traces.select { |tr| tr['Layer'] =~ /sidekiq/ }
    assert_equal 2, traces.select { |tr| tr['Layer'] =~ /actionview/ }.count
  end

end
