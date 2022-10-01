# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe "SolarWindsAPM::Config" do
  include Minitest::Hooks

  before(:all) do
    @default_config_path = File.join(Dir.pwd, 'solarwinds_apm_config.rb')
    @test_config_path = File.join(File.dirname(__FILE__), 'solarwinds_apm_config.rb')
    @template = File.join(File.dirname(File.dirname(File.dirname(__FILE__))),
                          'lib/rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb')
    @rails_config_path = File.join(Dir.pwd, 'config', 'initializers', 'solarwinds_apm.rb')
    FileUtils.mkdir_p(File.join(Dir.pwd, 'config', 'initializers'))
  end

  before do
    @loaded = SolarWindsAPM.loaded

    @config_mode = SolarWindsAPM::Config[:tracing_mode]
    @config_rate = SolarWindsAPM::Config[:sample_rate]
    @config_verbose = SolarWindsAPM::Config[:verbose]
    @config_key = SolarWindsAPM::Config[:service_key]
    @config_alias = SolarWindsAPM::Config[:hostname_alias]
    @config_level = SolarWindsAPM::Config[:debug_level]
    @config_regexp = SolarWindsAPM::Config[:dnt_regexp]

    @log_level = SolarWindsAPM.logger.level

    @env_config = ENV['SW_APM_CONFIG_RUBY']
    @env_key = ENV['SW_APM_SERVICE_KEY']
    @env_alias = ENV['SW_APM_HOSTNAME_ALIAS']
    @env_debug = ENV['SW_APM_DEBUG_LEVEL']
    @env_verbose = ENV['SW_APM_GEM_VERBOSE']

    ENV.delete('SW_APM_CONFIG_RUBY')
    ENV.delete('SW_APM_SERVICE_KEY')
    ENV.delete('SW_APM_HOSTNAME_ALIAS')
    ENV.delete('SW_APM_DEBUG_LEVEL')
    ENV.delete('SW_APM_GEM_VERBOSE')

    SolarWindsAPM::Config[:service_key] = nil
    SolarWindsAPM::Config[:hostname_alias] = nil
    SolarWindsAPM::Config[:debug_level] = nil
    SolarWindsAPM::Config[:verbose] = nil

    @verbose, $VERBOSE = $VERBOSE, nil
  end

  after do
    $VERBOSE = @verbose
    ENV.delete('SW_APM_CONFIG_RUBY')
    ENV.delete('SW_APM_SERVICE_KEY')
    ENV.delete('SW_APM_HOSTNAME_ALIAS')
    ENV.delete('SW_APM_DEBUG_LEVEL')
    ENV.delete('SW_APM_GEM_VERBOSE')

    ENV['SW_APM_CONFIG_RUBY'] = @env_config  if @env_config
    ENV['SW_APM_SERVICE_KEY']     = @env_key     if @env_key
    ENV['SW_APM_HOSTNAME_ALIAS']  = @env_alias   if @env_alias
    ENV['SW_APM_DEBUG_LEVEL']     = @env_debug   if @env_debug
    ENV['SW_APM_GEM_VERBOSE']     = @env_verbose if @env_verbose

    FileUtils.rm(@default_config_path, :force => true)
    FileUtils.rm(@rails_config_path, :force => true)
    FileUtils.rm(@test_config_path, :force => true)

    SolarWindsAPM.logger.level = @log_level

    SolarWindsAPM::Config[:tracing_mode] = @config_mode
    SolarWindsAPM::Config[:sample_rate] = @config_rate
    SolarWindsAPM::Config[:verbose] = @config_verbose
    SolarWindsAPM::Config[:service_key] = @config_key
    SolarWindsAPM::Config[:hostname_alias] = @config_alias
    SolarWindsAPM::Config[:debug_level] = @config_level
    SolarWindsAPM::Config[:dnt_regexp] = @config_regexp

    SolarWindsAPM.loaded = @loaded
  end

  it 'should read the settings from the config file' do
    File.open(@default_config_path, 'w') do |f|
      f.puts "SolarWindsAPM::Config[:service_key] = '11111111-1111-1111-1111-111111111111:the_service_name'"
      f.puts "SolarWindsAPM::Config[:hostname_alias] = 'my_service'"
      f.puts "SolarWindsAPM::Config[:debug_level] = 6"
      f.puts "SolarWindsAPM::Config[:verbose] = true"
    end
    ENV['SW_APM_CONFIG_RUBY'] = @default_config_path
    SolarWindsAPM::Config.load_config_file

    _(ENV['SW_APM_SERVICE_KEY']).must_be_nil
    _(SolarWindsAPM::Config[:service_key]).must_equal '11111111-1111-1111-1111-111111111111:the_service_name'

    _(ENV['SW_APM_HOSTNAME_ALIAS']).must_be_nil
    _(SolarWindsAPM::Config[:hostname_alias]).must_equal 'my_service'

    # logging happens in 2 places, oboe and ruby, we translate
    _(ENV['SW_APM_DEBUG_LEVEL']).must_be_nil
    _(SolarWindsAPM::Config[:debug_level]).must_equal 6
    _(SolarWindsAPM.logger.level).must_equal Logger::DEBUG

    _(ENV['SW_APM_GEM_VERBOSE']).must_be_nil
    _(SolarWindsAPM::Config[:verbose]).must_equal true
  end

  it 'should NOT override env vars with config file settings' do
    ENV['SW_APM_SERVICE_KEY'] = '22222222-2222-2222-2222-222222222222:the_service_name'
    ENV['SW_APM_HOSTNAME_ALIAS'] = 'my_other_service'
    ENV['SW_APM_DEBUG_LEVEL'] = '2'
    ENV['SW_APM_GEM_VERBOSE'] = 'TRUE'

    File.open(@default_config_path, 'w') do |f|
      f.puts "SolarWindsAPM::Config[:service_key] = '11111111-1111-1111-1111-111111111111:the_service_name'"
      f.puts "SolarWindsAPM::Config[:hostname_alias] = 'my_service'"
      f.puts "SolarWindsAPM::Config[:debug_level] = 6"
      f.puts "SolarWindsAPM::Config[:verbose] = false"
    end
    ENV['SW_APM_CONFIG_RUBY'] = @default_config_path
    SolarWindsAPM::Config.load_config_file

    _(ENV['SW_APM_SERVICE_KEY']).must_equal '22222222-2222-2222-2222-222222222222:the_service_name'
    _(ENV['SW_APM_HOSTNAME_ALIAS']).must_equal 'my_other_service'
    _(ENV['SW_APM_DEBUG_LEVEL']).must_equal '2'
    _(SolarWindsAPM.logger.level).must_equal Logger::WARN
    _(ENV['SW_APM_GEM_VERBOSE']).must_equal 'TRUE'
    _(SolarWindsAPM::Config[:verbose]).must_equal true
  end

  it 'should use default when there is a wrong debug level setting' do
    File.open(@default_config_path, 'w') do |f|
      f.puts "SolarWindsAPM::Config[:debug_level] = 7"
    end
    ENV['SW_APM_CONFIG_RUBY'] = @default_config_path
    SolarWindsAPM::Config.load_config_file

    _(ENV['SW_APM_DEBUG_LEVEL']).must_be_nil
    _(SolarWindsAPM::Config[:debug_level]).must_equal 3
    _(SolarWindsAPM.logger.level).must_equal Logger::INFO
  end

  it 'should accept -1 (disable logging)' do
    File.open(@default_config_path, 'w') do |f|
      f.puts "SolarWindsAPM::Config[:debug_level] = -1"
    end
    ENV['SW_APM_CONFIG_RUBY'] = @default_config_path
    SolarWindsAPM::Config.load_config_file

    _(ENV['SW_APM_DEBUG_LEVEL']).must_be_nil
    _(SolarWindsAPM::Config[:debug_level]).must_equal -1
    _(SolarWindsAPM.logger.level).must_equal 6
  end

  it "should accept 'true'/'TRUE'/'True'/... as true for VERBOSE" do
    File.open(@default_config_path, 'w') do |f|
      f.puts "SolarWindsAPM::Config[:verbose] = false"
    end
    ENV['SW_APM_CONFIG_RUBY'] = @default_config_path
    ENV['SW_APM_GEM_VERBOSE'] = 'FALSE'
    SolarWindsAPM::Config.load_config_file
    _(SolarWindsAPM::Config[:verbose]).wont_equal true

    ENV['SW_APM_GEM_VERBOSE'] = 'TRUE'
    SolarWindsAPM::Config.load_config_file
    _(SolarWindsAPM::Config[:verbose]).must_equal true

    ENV['SW_APM_GEM_VERBOSE'] = 'verbose'
    SolarWindsAPM::Config.load_config_file
    _(SolarWindsAPM::Config[:verbose]).wont_equal true

    ENV['SW_APM_GEM_VERBOSE'] = 'True'
    SolarWindsAPM::Config.load_config_file
    _(SolarWindsAPM::Config[:verbose]).must_equal true
  end

  it 'should have the correct defaults' do
    # Reset SolarWindsAPM::Config to defaults
    SolarWindsAPM::Config.initialize

    SolarWindsAPM::Config[:debug_level] = 3
    _(SolarWindsAPM::Config[:profiling]).must_equal :disabled
    _(SolarWindsAPM::Config[:verbose]).must_equal false
    _(SolarWindsAPM::Config[:tracing_mode]).must_equal :enabled
    _(SolarWindsAPM::Config[:log_traceId]).must_equal :never
    _(SolarWindsAPM::Config[:sanitize_sql]).must_equal true
    _(SolarWindsAPM::Config[:sanitize_sql_regexp]).must_equal '(\'[^\']*\'|\d*\.\d+|\d+|NULL)'
    _(SolarWindsAPM::Config[:sanitize_sql_opts]).must_equal Regexp::IGNORECASE

    _(SolarWindsAPM::Config[:dnt_regexp]).must_equal '\\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|otf|eot|ttf|woff|woff2|svg|less)(\\?.+){0,1}$'
    _(SolarWindsAPM::Config[:dnt_compiled].inspect).must_equal '/\\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|otf|eot|ttf|woff|woff2|svg|less)(\\?.+){0,1}$/i'
    _(SolarWindsAPM::Config[:dnt_opts]).must_equal Regexp::IGNORECASE

    _(SolarWindsAPM::Config[:graphql][:sanitize]).must_equal true
    _(SolarWindsAPM::Config[:graphql][:remove_comments]).must_equal true
    _(SolarWindsAPM::Config[:graphql][:transaction_name]).must_equal true

    _(SolarWindsAPM::Config[:rack_cache][:transaction_name]).must_equal true

    _(SolarWindsAPM::Config[:transaction_settings].is_a?(Hash)).must_equal true
    _(SolarWindsAPM::Config[:transaction_settings]).must_equal({ url: [] })

    _(SolarWindsAPM::Config[:report_rescued_errors]).must_equal false
    _(SolarWindsAPM::Config[:ec2_metadata_timeout]).must_equal 1000

    _(SolarWindsAPM::Config[:bunnyconsumer][:controller]).must_equal :app_id
    _(SolarWindsAPM::Config[:bunnyconsumer][:action]).must_equal :type

    # Verify the number of individual instrumentations ...
    instrumentation = SolarWindsAPM::Config.instrumentation
    _(instrumentation.count).must_equal 32

    # ... and make sure they are enabled by default
    instrumentation.each do |key|
      _(SolarWindsAPM::Config[key][:enabled]).must_equal true, key
    end

    _(SolarWindsAPM::Config[:bunnyconsumer][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:curb][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:excon][:log_args]).must_equal true
    # _(SolarWindsAPM::Config[:faraday][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:httpclient][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:mongo][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:nethttp][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:rack][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:resqueclient][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:resqueworker][:log_args]).must_equal true
    # _(SolarWindsAPM::Config[:rest_client][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:sidekiqclient][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:sidekiqworker][:log_args]).must_equal true
    _(SolarWindsAPM::Config[:typhoeus][:log_args]).must_equal true

    _(SolarWindsAPM::Config[:action_controller][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:action_controller_api][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:action_view][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:active_record][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:bunnyconsumer][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:curb][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:dalli][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:delayed_jobclient][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:delayed_jobworker][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:excon][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:faraday][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:grape][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:grpc_client][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:grpc_server][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:httpclient][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:memcached][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:mongo][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:moped][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:nethttp][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:padrino][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:rack][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:redis][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:resqueclient][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:resqueworker][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:rest_client][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:sequel][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:sidekiqworker][:collect_backtraces]).must_equal false
    _(SolarWindsAPM::Config[:sinatra][:collect_backtraces]).must_equal true
    _(SolarWindsAPM::Config[:typhoeus][:collect_backtraces]).must_equal false
  end

  def test_deprecated_config_accessors
    SolarWindsAPM::Config.initialize

    http_clients = SolarWindsAPM::Config.http_clients

    SolarWindsAPM::Config[:include_remote_url_params] = false
    http_clients.each do |i|
      _(SolarWindsAPM::Config[i][:log_args]).must_equal false
    end

    SolarWindsAPM::Config[:include_remote_url_params] = true
    http_clients.each do |i|
      _(SolarWindsAPM::Config[i][:log_args]).must_equal true
    end

    SolarWindsAPM::Config[:include_url_query_params] = false
    _(SolarWindsAPM::Config[:rack][:log_args]).must_equal false

    SolarWindsAPM::Config[:include_url_query_params] = true
    _(SolarWindsAPM::Config[:rack][:log_args]).must_equal true
  end

  def test_should_correct_negative_sample_rate
    SolarWindsAPM::Config[:sample_rate] = -3
    SolarWindsAPM::Config.initialize

    _(SolarWindsAPM::Config[:sample_rate]).must_equal 0
    _(SolarWindsAPM::Config.sample_rate).must_equal 0
  end

  def test_should_correct_large_sample_rate
    SolarWindsAPM::Config[:sample_rate] = 1_000_000_000
    SolarWindsAPM::Config.initialize

    _(SolarWindsAPM::Config[:sample_rate]).must_equal 1_000_000
    _(SolarWindsAPM::Config.sample_rate).must_equal 1_000_000
  end

  def test_should_correct_non_numeric_sample_rate
    SolarWindsAPM::Config[:sample_rate] = "summertime"
    SolarWindsAPM::Config.initialize

    _(SolarWindsAPM::Config[:sample_rate]).must_equal 0
    _(SolarWindsAPM::Config.sample_rate).must_equal 0
  end


  ############################################
  ### Tests for DNT (do not trace) configs ###
  ############################################
  describe "asset_filtering" do
    it 'use :dnt_regexp' do
      SolarWindsAPM::Config[:dnt_regexp] = '\\.gif|\\.js|\\.css|\\.gz(\\?.+){0,1}$'
      SolarWindsAPM::Config[:dnt_opts] = Regexp::IGNORECASE
      SolarWindsAPM::Config.dnt_compile

      _(SolarWindsAPM::Config[:dnt_compiled].inspect).must_equal '/\\.gif|\\.js|\\.css|\\.gz(\\?.+){0,1}$/i'
    end

    it 'no regex leads to no :dnt_compiled' do
      SolarWindsAPM::Config[:dnt_regexp] = ''
      SolarWindsAPM::Config[:dnt_opts] = Regexp::IGNORECASE
      SolarWindsAPM::Config.dnt_compile

      _(SolarWindsAPM::Config[:dnt_compiled]).must_be_nil
    end
  end

  #########################################
  ### Tests for loading the config file ###
  #########################################

  it 'should not load a file if no path and no default file are found' do
    SolarWindsAPM::Config.expects(:load).times(0)
    SolarWindsAPM::Config.load_config_file
  end

  it 'should load configs from default file' do
    FileUtils.cp(@template, @default_config_path)

    SolarWindsAPM::Config.expects(:load).with(@default_config_path).times(1)
    SolarWindsAPM::Config.load_config_file
  end

  it 'should load config file from env var' do
    ENV['SW_APM_CONFIG_RUBY'] = @test_config_path
    FileUtils.cp(@template, @test_config_path)

    SolarWindsAPM::Config.expects(:load).with(@test_config_path).times(1)
    SolarWindsAPM::Config.load_config_file
  end

  it 'should find the file if the path points to a directory' do
    ENV['SW_APM_CONFIG_RUBY'] = File.dirname(@test_config_path)
    FileUtils.cp(@template, @test_config_path)

    SolarWindsAPM::Config.expects(:load).with(@test_config_path).times(1)
    SolarWindsAPM::Config.load_config_file
  end

  it 'should load the rails default config file' do
    # even though rails will load it as well, but we don't have a reliable way to detect a rails app
    FileUtils.cp(@template, @rails_config_path)

    SolarWindsAPM::Config.expects(:load).with(@rails_config_path).times(1)
    SolarWindsAPM::Config.load_config_file
  end

  it 'should print a message if env var does not point to a file' do
    ENV['SW_APM_CONFIG_RUBY'] = 'non_existing_file'

    SolarWindsAPM.logger.expects(:warn).once
    SolarWindsAPM::Config.load_config_file
  end

  it 'should print a message if multiple config files are configured' do
    FileUtils.cp(@template, @default_config_path)
    FileUtils.cp(@template, @test_config_path)
    ENV['SW_APM_CONFIG_RUBY'] = @test_config_path

    SolarWindsAPM.logger.expects(:warn).once
    SolarWindsAPM::Config.expects(:load).with(@test_config_path).times(1)
    SolarWindsAPM::Config.load_config_file
  end

  describe "profiling_interval configuration" do
    before do
      SolarWindsAPM::Config.load_config_file
    end

    it 'accepts the minimum value of 1' do
      SolarWindsAPM::Config['profiling_interval'] = 1
      _(SolarWindsAPM::Config.profiling_interval).must_equal 1
    end

    it 'accepts the maximum value of 100' do
      SolarWindsAPM::Config['profiling_interval'] = 100
      _(SolarWindsAPM::Config.profiling_interval).must_equal 100
    end

    it 'sets the default of 10 for invalid entries' do
      SolarWindsAPM::Config['profiling_interval'] = -1

      _(SolarWindsAPM::Config.profiling_interval).must_equal 10
    end

    it 'sets the maximum of 100 for values > 100' do
      SolarWindsAPM::Config['profiling_interval'] = 1000000000000000000000000000000

      _(SolarWindsAPM::Config.profiling_interval).must_equal 100
    end
  end

end
