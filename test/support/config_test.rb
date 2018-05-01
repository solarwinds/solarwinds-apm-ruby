# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

class ConfigTest
  describe "AppOpticsAPM::Config" do

    @@default_config_path = File.join(Dir.pwd, 'appoptics_apm_config.rb')
    @@test_config_path = File.join(File.dirname(__FILE__), 'appoptics_apm_config.rb')
    @@template = File.join(File.dirname(File.dirname(File.dirname(__FILE__))),
                           'lib/rails/generators/appoptics_apm/templates/appoptics_apm_initializer.rb')
    @@rails_config_path = File.join(Dir.pwd, 'config', 'initializers', 'appoptics_apm.rb')

    before do
      ENV.delete('APPOPTICS_APM_CONFIG_RUBY')
      FileUtils.rm(@@default_config_path, :force => true)
      FileUtils.rm(@@rails_config_path, :force => true)
      FileUtils.rm(@@test_config_path, :force => true)
    end

    after do
      # Set back to always trace mode
      AppOpticsAPM::Config[:tracing_mode] = "always"
      AppOpticsAPM::Config[:sample_rate] = 1000000
    end

    after(:all) do
      ENV.delete('APPOPTICS_APM_CONFIG_RUBY')
      FileUtils.rm(@@default_config_path, :force => true)
      FileUtils.rm(@@rails_config_path, :force => true)
      FileUtils.rm(@@test_config_path, :force => true)
    end

    it 'should have the correct instrumentation defaults' do
      # Reset AppOpticsAPM::Config to defaults
      AppOpticsAPM::Config.initialize

      AppOpticsAPM::Config[:tracing_mode].must_equal :always
      AppOpticsAPM::Config[:verbose].must_equal ENV.key?('APPOPTICS_GEM_VERBOSE') && ENV['APPOPTICS_GEM_VERBOSE'] == 'true' ? true : false

      AppOpticsAPM::Config[:sanitize_sql].must_equal true
      AppOpticsAPM::Config[:sanitize_sql_regexp].must_equal '(\'[\s\S][^\']*\'|\d*\.\d+|\d+|NULL)'
      AppOpticsAPM::Config[:sanitize_sql_opts].must_equal Regexp::IGNORECASE

      AppOpticsAPM::Config[:dnt_regexp].must_equal '\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|otf|eot|ttf|woff|woff2|svg|less)(\?.+){0,1}$'
      AppOpticsAPM::Config[:dnt_opts].must_equal Regexp::IGNORECASE

      AppOpticsAPM::Config[:blacklist].is_a?(Array).must_equal true
      AppOpticsAPM::Config[:report_rescued_errors].must_equal false

      AppOpticsAPM::Config[:bunnyconsumer][:controller].must_equal :app_id
      AppOpticsAPM::Config[:bunnyconsumer][:action].must_equal :type

      # Verify the number of individual instrumentations
      instrumentation = AppOpticsAPM::Config.instrumentation
      instrumentation.count.must_equal 29

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

      AppOpticsAPM::Config[:bunnyconsumer][:log_args].must_equal true
      AppOpticsAPM::Config[:curb][:log_args].must_equal true
      # AppOpticsAPM::Config[:em_http_request][:log_args].must_equal true
      AppOpticsAPM::Config[:excon][:log_args].must_equal true
      # AppOpticsAPM::Config[:faraday][:log_args].must_equal true
      AppOpticsAPM::Config[:httpclient][:log_args].must_equal true
      AppOpticsAPM::Config[:mongo][:log_args].must_equal true
      AppOpticsAPM::Config[:nethttp][:log_args].must_equal true
      AppOpticsAPM::Config[:rack][:log_args].must_equal true
      AppOpticsAPM::Config[:resqueclient][:log_args].must_equal true
      AppOpticsAPM::Config[:resqueworker][:log_args].must_equal true
      # AppOpticsAPM::Config[:rest_client][:log_args].must_equal true
      AppOpticsAPM::Config[:sidekiqclient][:log_args].must_equal true
      AppOpticsAPM::Config[:sidekiqworker][:log_args].must_equal true
      AppOpticsAPM::Config[:typhoeus][:log_args].must_equal true

      AppOpticsAPM::Config[:action_controller][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:action_controller_api][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:action_view][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:active_record][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:bunnyclient][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:bunnyconsumer][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:cassandra][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:curb][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:dalli][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:delayed_jobclient][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:delayed_jobworker][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:em_http_request][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:excon][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:faraday][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:grape][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:httpclient][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:memcached][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:mongo][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:moped][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:nethttp][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:rack][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:redis][:collect_backtraces].must_equal false
      AppOpticsAPM::Config[:resqueclient][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:resqueworker][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:rest_client][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:sequel][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:sidekiqclient][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:sidekiqworker][:collect_backtraces].must_equal true
      AppOpticsAPM::Config[:typhoeus][:collect_backtraces].must_equal false
    end

    def test_deprecated_config_accessors
      AppOpticsAPM::Config.initialize

      http_clients = AppOpticsAPM::Config.http_clients

      AppOpticsAPM::Config[:include_remote_url_params] = false
      http_clients.each do |i|
        AppOpticsAPM::Config[i][:log_args].must_equal false
      end

      AppOpticsAPM::Config[:include_remote_url_params] = true
      http_clients.each do |i|
        AppOpticsAPM::Config[i][:log_args].must_equal true
      end

      AppOpticsAPM::Config[:include_url_query_params] = false
      AppOpticsAPM::Config[:rack][:log_args].must_equal false

      AppOpticsAPM::Config[:include_url_query_params] = true
      AppOpticsAPM::Config[:rack][:log_args].must_equal true
    end

    def test_should_correct_negative_sample_rate
      AppOpticsAPM::Config[:sample_rate] = -3
      AppOpticsAPM::Config.initialize

      AppOpticsAPM::Config[:sample_rate].must_equal 0
      AppOpticsAPM::Config.sample_rate.must_equal 0
    end

    def test_should_correct_large_sample_rate
      AppOpticsAPM::Config[:sample_rate] = 1_000_000_000
      AppOpticsAPM::Config.initialize

      AppOpticsAPM::Config[:sample_rate].must_equal 1_000_000
      AppOpticsAPM::Config.sample_rate.must_equal 1_000_000
    end

    def test_should_correct_non_numeric_sample_rate
      AppOpticsAPM::Config[:sample_rate] = "summertime"
      AppOpticsAPM::Config.initialize

      AppOpticsAPM::Config[:sample_rate].must_equal 0
      AppOpticsAPM::Config.sample_rate.must_equal 0
    end

    #########################################
    ### Tests for loading the config file ###
    #########################################

    it 'should not load a file if no path and no default file are found' do
      AppOpticsAPM::Config.expects(:load).times(0)
      AppOpticsAPM::Config.load_config_file
    end

    it 'should load configs from default file' do
      FileUtils.cp(@@template, @@default_config_path)

      AppOpticsAPM::Config.expects(:load).with(@@default_config_path).times(1)
      AppOpticsAPM::Config.load_config_file
    end

    it 'should load config file from env var' do
      ENV['APPOPTICS_APM_CONFIG_RUBY'] = @@test_config_path
      FileUtils.cp(@@template, @@test_config_path)

      AppOpticsAPM::Config.expects(:load).with(@@test_config_path).times(1)
      AppOpticsAPM::Config.load_config_file
    end

    it 'should find the file if the path points to a directory' do
      ENV['APPOPTICS_APM_CONFIG_RUBY'] = File.dirname(@@test_config_path)
      FileUtils.cp(@@template, @@test_config_path)

      AppOpticsAPM::Config.expects(:load).with(@@test_config_path).times(1)
      AppOpticsAPM::Config.load_config_file
    end

    it 'should load the rails default config file' do
      # even though rails will load it as well, but we don't have a reliable way to detect a rails app
      FileUtils.cp(@@template, @@rails_config_path)

      AppOpticsAPM::Config.expects(:load).with(@@rails_config_path).times(1)
      AppOpticsAPM::Config.load_config_file
    end

    it 'should print a message if env var does not point to a file' do
      ENV['APPOPTICS_APM_CONFIG_RUBY'] = 'non_existing_file'

      $stderr.expects(:puts).at_least_once
      AppOpticsAPM::Config.load_config_file
    end

    it 'should print a message if multiple config files are configured' do
      FileUtils.cp(@@template, @@default_config_path)
      FileUtils.cp(@@template, @@test_config_path)
      ENV['APPOPTICS_APM_CONFIG_RUBY'] = @@test_config_path

      $stderr.expects(:puts).at_least_once
      AppOpticsAPM::Config.expects(:load).with(@@test_config_path).times(1)
      AppOpticsAPM::Config.load_config_file
    end
  end
end
