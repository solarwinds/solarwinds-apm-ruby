# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "AppOptics::Config" do
  after do
    # Set back to always trace mode
    AppOptics::Config[:tracing_mode] = "always"
    AppOptics::Config[:sample_rate] = 1000000
  end

  it 'should have the correct default values' do
    # Reset AppOptics::Config to defaults
    AppOptics::Config.initialize

    # FIXME: We set the APPOPTICS_GEM_VERBOSE env for the
    # ____   test suite so this assertion is not going to fly
    #
    # AppOptics::Config[:verbose].must_equal false

    # TODO: Is there anything we should test here?
  end

  it 'should have the correct instrumentation defaults' do
    # Reset AppOptics::Config to defaults
    AppOptics::Config.initialize

    instrumentation = AppOptics::Config.instrumentation

    # Verify the number of individual instrumentations
    instrumentation.count.must_equal 30

    AppOptics::Config[:action_controller][:enabled].must_equal true
    AppOptics::Config[:action_controller_api][:enabled].must_equal true
    AppOptics::Config[:action_view][:enabled].must_equal true
    AppOptics::Config[:active_record][:enabled].must_equal true
    AppOptics::Config[:bunnyclient][:enabled].must_equal true
    AppOptics::Config[:bunnyconsumer][:enabled].must_equal true
    AppOptics::Config[:cassandra][:enabled].must_equal true
    AppOptics::Config[:curb][:enabled].must_equal true
    AppOptics::Config[:dalli][:enabled].must_equal true
    AppOptics::Config[:delayed_jobclient][:enabled].must_equal true
    AppOptics::Config[:delayed_jobworker][:enabled].must_equal true
    AppOptics::Config[:em_http_request][:enabled].must_equal false
    AppOptics::Config[:excon][:enabled].must_equal true
    AppOptics::Config[:faraday][:enabled].must_equal true
    AppOptics::Config[:grape][:enabled].must_equal true
    AppOptics::Config[:httpclient][:enabled].must_equal true
    AppOptics::Config[:nethttp][:enabled].must_equal true
    AppOptics::Config[:memcached][:enabled].must_equal true
    AppOptics::Config[:memcache][:enabled].must_equal true
    AppOptics::Config[:mongo][:enabled].must_equal true
    AppOptics::Config[:moped][:enabled].must_equal true
    AppOptics::Config[:rack][:enabled].must_equal true
    AppOptics::Config[:redis][:enabled].must_equal true
    AppOptics::Config[:resqueclient][:enabled].must_equal true
    AppOptics::Config[:resqueworker][:enabled].must_equal true
    AppOptics::Config[:rest_client][:enabled].must_equal true
    AppOptics::Config[:sequel][:enabled].must_equal true
    AppOptics::Config[:sidekiqclient][:enabled].must_equal true
    AppOptics::Config[:sidekiqworker][:enabled].must_equal true
    AppOptics::Config[:typhoeus][:enabled].must_equal true

    AppOptics::Config[:action_controller][:log_args].must_equal true
    AppOptics::Config[:action_controller_api][:log_args].must_equal true
    AppOptics::Config[:action_view][:log_args].must_equal true
    AppOptics::Config[:active_record][:log_args].must_equal true
    AppOptics::Config[:bunnyclient][:log_args].must_equal true
    AppOptics::Config[:bunnyconsumer][:log_args].must_equal true
    AppOptics::Config[:cassandra][:log_args].must_equal true
    AppOptics::Config[:curb][:log_args].must_equal true
    AppOptics::Config[:dalli][:log_args].must_equal true
    AppOptics::Config[:delayed_jobclient][:log_args].must_equal true
    AppOptics::Config[:delayed_jobworker][:log_args].must_equal true
    AppOptics::Config[:em_http_request][:log_args].must_equal true
    AppOptics::Config[:excon][:log_args].must_equal true
    AppOptics::Config[:faraday][:log_args].must_equal true
    AppOptics::Config[:grape][:log_args].must_equal true
    AppOptics::Config[:httpclient][:log_args].must_equal true
    AppOptics::Config[:nethttp][:log_args].must_equal true
    AppOptics::Config[:memcached][:log_args].must_equal true
    AppOptics::Config[:memcache][:log_args].must_equal true
    AppOptics::Config[:mongo][:log_args].must_equal true
    AppOptics::Config[:moped][:log_args].must_equal true
    AppOptics::Config[:rack][:log_args].must_equal true
    AppOptics::Config[:redis][:log_args].must_equal true
    AppOptics::Config[:resqueclient][:log_args].must_equal true
    AppOptics::Config[:resqueworker][:log_args].must_equal true
    AppOptics::Config[:rest_client][:log_args].must_equal true
    AppOptics::Config[:sequel][:log_args].must_equal true
    AppOptics::Config[:sidekiqclient][:log_args].must_equal true
    AppOptics::Config[:sidekiqworker][:log_args].must_equal true
    AppOptics::Config[:typhoeus][:log_args].must_equal true

    AppOptics::Config[:blacklist].is_a?(Array).must_equal true

    AppOptics::Config[:dnt_regexp].must_equal '\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|ttf|woff|svg|less)(\?.+){0,1}$'
    AppOptics::Config[:dnt_opts].must_equal Regexp::IGNORECASE
  end

  def test_should_obey_globals
    # Reset AppOptics::Config to defaults
    AppOptics::Config.initialize

    http_clients = AppOptics::Config.http_clients

    # Restore these at the end
    @url_query_params  = AppOptics::Config[:include_url_query_params]
    @remote_url_params = AppOptics::Config[:include_remote_url_params]

    # After setting global options, the per instrumentation
    # equivalents should follow suit.

    #
    # :include_remote_url_params
    #

    # Check defaults
    AppOptics::Config[:include_remote_url_params].must_equal true
    http_clients.each do |i|
      AppOptics::Config[i][:log_args].must_equal true
    end

    # Check obedience
    AppOptics::Config[:include_remote_url_params] = false
    http_clients.each do |i|
      AppOptics::Config[i][:log_args].must_equal false
    end

    #
    # :include_url_query_params
    #

    # Check default
    AppOptics::Config[:include_url_query_params].must_equal true
    AppOptics::Config[:rack][:log_args].must_equal true

    # Check obedience
    AppOptics::Config[:include_url_query_params] = false
    AppOptics::Config[:rack][:log_args].must_equal false

    # Restore the previous values
    AppOptics::Config[:include_url_query_params] = @url_query_params
    AppOptics::Config[:include_remote_url_params] = @remote_url_params
  end
end
