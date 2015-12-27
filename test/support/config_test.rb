# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

describe "TraceView::Config" do
  after do
    # Set back to always trace mode
    TraceView::Config[:tracing_mode] = "always"
    TraceView::Config[:sample_rate] = 1000000
  end

  it 'should have the correct default values' do
    # Reset TraceView::Config to defaults
    TraceView::Config.initialize

    # FIXME: We set the TRACEVIEW_GEM_VERBOSE env for the
    # test suite so this assertion is not going to fly
    #
    # TraceView::Config[:verbose].must_equal false

    TraceView::Config[:tracing_mode].must_equal "through"
    TraceView::Config[:reporter_host].must_equal "127.0.0.1"
  end

  it 'should have the correct instrumentation defaults' do
    # Reset TraceView::Config to defaults
    TraceView::Config.initialize

    instrumentation = TraceView::Config.instrumentation

    # Verify the number of individual instrumentations
    instrumentation.count.must_equal 27

    TraceView::Config[:action_controller][:enabled].must_equal true
    TraceView::Config[:action_view][:enabled].must_equal true
    TraceView::Config[:active_record][:enabled].must_equal true
    TraceView::Config[:cassandra][:enabled].must_equal true
    TraceView::Config[:curb][:enabled].must_equal true
    TraceView::Config[:dalli][:enabled].must_equal true
    TraceView::Config[:delayed_jobclient][:enabled].must_equal true
    TraceView::Config[:delayed_jobworker][:enabled].must_equal true
    TraceView::Config[:em_http_request][:enabled].must_equal false
    TraceView::Config[:excon][:enabled].must_equal true
    TraceView::Config[:faraday][:enabled].must_equal true
    TraceView::Config[:grape][:enabled].must_equal true
    TraceView::Config[:httpclient][:enabled].must_equal true
    TraceView::Config[:nethttp][:enabled].must_equal true
    TraceView::Config[:memcached][:enabled].must_equal true
    TraceView::Config[:memcache][:enabled].must_equal true
    TraceView::Config[:mongo][:enabled].must_equal true
    TraceView::Config[:moped][:enabled].must_equal true
    TraceView::Config[:rack][:enabled].must_equal true
    TraceView::Config[:redis][:enabled].must_equal true
    TraceView::Config[:resqueclient][:enabled].must_equal true
    TraceView::Config[:resqueworker][:enabled].must_equal true
    TraceView::Config[:rest_client][:enabled].must_equal true
    TraceView::Config[:sequel][:enabled].must_equal true
    TraceView::Config[:sidekiqclient][:enabled].must_equal true
    TraceView::Config[:sidekiqworker][:enabled].must_equal true
    TraceView::Config[:typhoeus][:enabled].must_equal true

    TraceView::Config[:action_controller][:log_args].must_equal true
    TraceView::Config[:action_view][:log_args].must_equal true
    TraceView::Config[:active_record][:log_args].must_equal true
    TraceView::Config[:cassandra][:log_args].must_equal true
    TraceView::Config[:curb][:log_args].must_equal true
    TraceView::Config[:dalli][:log_args].must_equal true
    TraceView::Config[:delayed_jobclient][:log_args].must_equal true
    TraceView::Config[:delayed_jobworker][:log_args].must_equal true
    TraceView::Config[:em_http_request][:log_args].must_equal true
    TraceView::Config[:excon][:log_args].must_equal true
    TraceView::Config[:faraday][:log_args].must_equal true
    TraceView::Config[:grape][:log_args].must_equal true
    TraceView::Config[:httpclient][:log_args].must_equal true
    TraceView::Config[:nethttp][:log_args].must_equal true
    TraceView::Config[:memcached][:log_args].must_equal true
    TraceView::Config[:memcache][:log_args].must_equal true
    TraceView::Config[:mongo][:log_args].must_equal true
    TraceView::Config[:moped][:log_args].must_equal true
    TraceView::Config[:rack][:log_args].must_equal true
    TraceView::Config[:redis][:log_args].must_equal true
    TraceView::Config[:resqueclient][:log_args].must_equal true
    TraceView::Config[:resqueworker][:log_args].must_equal true
    TraceView::Config[:rest_client][:log_args].must_equal true
    TraceView::Config[:sequel][:log_args].must_equal true
    TraceView::Config[:sidekiqclient][:log_args].must_equal true
    TraceView::Config[:sidekiqworker][:log_args].must_equal true
    TraceView::Config[:typhoeus][:log_args].must_equal true

    TraceView::Config[:blacklist].is_a?(Array).must_equal true

    TraceView::Config[:dnt_regexp].must_equal "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|ttf|woff|svg|less)$"
    TraceView::Config[:dnt_opts].must_equal Regexp::IGNORECASE
  end

  def test_should_obey_globals
    # Reset TraceView::Config to defaults
    TraceView::Config.initialize

    http_clients = TraceView::Config.http_clients

    # Restore these at the end
    @url_query_params  = TraceView::Config[:include_url_query_params]
    @remote_url_params = TraceView::Config[:include_remote_url_params]

    # After setting global options, the per instrumentation
    # equivalents should follow suit.

    #
    # :include_remote_url_params
    #

    # Check defaults
    TraceView::Config[:include_remote_url_params].must_equal true
    http_clients.each do |i|
      TraceView::Config[i][:log_args].must_equal true
    end

    # Check obedience
    TraceView::Config[:include_remote_url_params] = false
    http_clients.each do |i|
      TraceView::Config[i][:log_args].must_equal false
    end

    #
    # :include_url_query_params
    #

    # Check default
    TraceView::Config[:include_url_query_params].must_equal true
    TraceView::Config[:rack][:log_args].must_equal true

    # Check obedience
    TraceView::Config[:include_url_query_params] = false
    TraceView::Config[:rack][:log_args].must_equal false

    # Restore the previous values
    TraceView::Config[:include_url_query_params] = @url_query_params
    TraceView::Config[:include_remote_url_params] = @remote_url_params
  end
end
