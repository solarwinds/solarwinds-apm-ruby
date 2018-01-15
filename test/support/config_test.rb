# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "AppOpticsAPM::Config" do
  after do
    # Set back to always trace mode
    AppOpticsAPM::Config[:tracing_mode] = "always"
    AppOpticsAPM::Config[:sample_rate] = 1000000
  end

  it 'should have the correct default values' do
    # Reset AppOpticsAPM::Config to defaults
    AppOpticsAPM::Config.initialize

    # FIXME: We set the APPOPTICS_GEM_VERBOSE env for the
    # ____   test suite so this assertion is not going to fly
    #
    # AppOpticsAPM::Config[:verbose].must_equal false

    # TODO: Is there anything we should test here?
  end

  it 'should have the correct instrumentation defaults' do
    # Reset AppOpticsAPM::Config to defaults
    AppOpticsAPM::Config.initialize

    instrumentation = AppOpticsAPM::Config.instrumentation

    # Verify the number of individual instrumentations
    instrumentation.count.must_equal 30

    AppOpticsAPM::Config[:action_controller][:enabled].must_equal true
    AppOpticsAPM::Config[:action_controller_api][:enabled].must_equal true
    AppOpticsAPM::Config[:action_view][:enabled].must_equal true
    AppOpticsAPM::Config[:active_record][:enabled].must_equal true
    AppOpticsAPM::Config[:bunnyclient][:enabled].must_equal true
    AppOpticsAPM::Config[:bunnyconsumer][:enabled].must_equal true
    AppOpticsAPM::Config[:cassandra][:enabled].must_equal true
    AppOpticsAPM::Config[:curb][:enabled].must_equal true
    AppOpticsAPM::Config[:dalli][:enabled].must_equal true
    AppOpticsAPM::Config[:delayed_jobclient][:enabled].must_equal true
    AppOpticsAPM::Config[:delayed_jobworker][:enabled].must_equal true
    AppOpticsAPM::Config[:em_http_request][:enabled].must_equal false
    AppOpticsAPM::Config[:excon][:enabled].must_equal true
    AppOpticsAPM::Config[:faraday][:enabled].must_equal true
    AppOpticsAPM::Config[:grape][:enabled].must_equal true
    AppOpticsAPM::Config[:httpclient][:enabled].must_equal true
    AppOpticsAPM::Config[:nethttp][:enabled].must_equal true
    AppOpticsAPM::Config[:memcached][:enabled].must_equal true
    AppOpticsAPM::Config[:memcache][:enabled].must_equal true
    AppOpticsAPM::Config[:mongo][:enabled].must_equal true
    AppOpticsAPM::Config[:moped][:enabled].must_equal true
    AppOpticsAPM::Config[:rack][:enabled].must_equal true
    AppOpticsAPM::Config[:redis][:enabled].must_equal true
    AppOpticsAPM::Config[:resqueclient][:enabled].must_equal true
    AppOpticsAPM::Config[:resqueworker][:enabled].must_equal true
    AppOpticsAPM::Config[:rest_client][:enabled].must_equal true
    AppOpticsAPM::Config[:sequel][:enabled].must_equal true
    AppOpticsAPM::Config[:sidekiqclient][:enabled].must_equal true
    AppOpticsAPM::Config[:sidekiqworker][:enabled].must_equal true
    AppOpticsAPM::Config[:typhoeus][:enabled].must_equal true

    AppOpticsAPM::Config[:action_controller][:log_args].must_equal true
    AppOpticsAPM::Config[:action_controller_api][:log_args].must_equal true
    AppOpticsAPM::Config[:action_view][:log_args].must_equal true
    AppOpticsAPM::Config[:active_record][:log_args].must_equal true
    AppOpticsAPM::Config[:bunnyclient][:log_args].must_equal true
    AppOpticsAPM::Config[:bunnyconsumer][:log_args].must_equal true
    AppOpticsAPM::Config[:cassandra][:log_args].must_equal true
    AppOpticsAPM::Config[:curb][:log_args].must_equal true
    AppOpticsAPM::Config[:dalli][:log_args].must_equal true
    AppOpticsAPM::Config[:delayed_jobclient][:log_args].must_equal true
    AppOpticsAPM::Config[:delayed_jobworker][:log_args].must_equal true
    AppOpticsAPM::Config[:em_http_request][:log_args].must_equal true
    AppOpticsAPM::Config[:excon][:log_args].must_equal true
    AppOpticsAPM::Config[:faraday][:log_args].must_equal true
    AppOpticsAPM::Config[:grape][:log_args].must_equal true
    AppOpticsAPM::Config[:httpclient][:log_args].must_equal true
    AppOpticsAPM::Config[:nethttp][:log_args].must_equal true
    AppOpticsAPM::Config[:memcached][:log_args].must_equal true
    AppOpticsAPM::Config[:memcache][:log_args].must_equal true
    AppOpticsAPM::Config[:mongo][:log_args].must_equal true
    AppOpticsAPM::Config[:moped][:log_args].must_equal true
    AppOpticsAPM::Config[:rack][:log_args].must_equal true
    AppOpticsAPM::Config[:redis][:log_args].must_equal true
    AppOpticsAPM::Config[:resqueclient][:log_args].must_equal true
    AppOpticsAPM::Config[:resqueworker][:log_args].must_equal true
    AppOpticsAPM::Config[:rest_client][:log_args].must_equal true
    AppOpticsAPM::Config[:sequel][:log_args].must_equal true
    AppOpticsAPM::Config[:sidekiqclient][:log_args].must_equal true
    AppOpticsAPM::Config[:sidekiqworker][:log_args].must_equal true
    AppOpticsAPM::Config[:typhoeus][:log_args].must_equal true

    AppOpticsAPM::Config[:blacklist].is_a?(Array).must_equal true

    AppOpticsAPM::Config[:dnt_regexp].must_equal '\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|otf|eot|ttf|woff|woff2|svg|less)(\?.+){0,1}$'
    AppOpticsAPM::Config[:dnt_opts].must_equal Regexp::IGNORECASE

    AppOpticsAPM::Config[:sanitize_sql].must_equal true
  end

  def test_should_obey_globals
    # Reset AppOpticsAPM::Config to defaults
    AppOpticsAPM::Config.initialize

    http_clients = AppOpticsAPM::Config.http_clients

    # Restore these at the end
    @url_query_params  = AppOpticsAPM::Config[:include_url_query_params]
    @remote_url_params = AppOpticsAPM::Config[:include_remote_url_params]

    # After setting global options, the per instrumentation
    # equivalents should follow suit.

    #
    # :include_remote_url_params
    #

    # Check defaults
    AppOpticsAPM::Config[:include_remote_url_params].must_equal true
    http_clients.each do |i|
      AppOpticsAPM::Config[i][:log_args].must_equal true
    end

    # Check obedience
    AppOpticsAPM::Config[:include_remote_url_params] = false
    http_clients.each do |i|
      AppOpticsAPM::Config[i][:log_args].must_equal false
    end

    #
    # :include_url_query_params
    #

    # Check default
    AppOpticsAPM::Config[:include_url_query_params].must_equal true
    AppOpticsAPM::Config[:rack][:log_args].must_equal true

    # Check obedience
    AppOpticsAPM::Config[:include_url_query_params] = false
    AppOpticsAPM::Config[:rack][:log_args].must_equal false

    # Restore the previous values
    AppOpticsAPM::Config[:include_url_query_params] = @url_query_params
    AppOpticsAPM::Config[:include_remote_url_params] = @remote_url_params
  end
end
