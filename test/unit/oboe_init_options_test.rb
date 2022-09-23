# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'OboeInitOptions' do

  before do
    @env = ENV.to_hash
    # lets suppress logging, because we will log a lot of errors when testing the service_key
    @log_level = SolarWindsAPM.logger.level
    SolarWindsAPM.logger.level = 6
  end

  after do
    @env.each { |k, v| ENV[k] = v }
    SolarWindsAPM::OboeInitOptions.instance.re_init
    SolarWindsAPM.logger.level = @log_level
  end

  it 'sets all options from ENV vars' do
    ENV.delete('SW_APM_GEM_TEST')

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:test_app'
    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_COLLECTOR'] = 'string_2'
    ENV['SW_APM_TRUSTEDPATH'] = 'string_3'
    ENV['SW_APM_HOSTNAME_ALIAS'] = 'string_4'
    ENV['SW_APM_BUFSIZE'] = '11'
    ENV['SW_APM_LOGFILE'] = 'string_5'
    ENV['SW_APM_DEBUG_LEVEL'] = '2'
    ENV['SW_APM_TRACE_METRICS'] = '3'
    ENV['SW_APM_HISTOGRAM_PRECISION'] = '4'
    ENV['SW_APM_MAX_TRANSACTIONS'] = '5'
    ENV['SW_APM_FLUSH_MAX_WAIT_TIME'] = '6'
    ENV['SW_APM_EVENTS_FLUSH_INTERVAL'] = '7'
    ENV['SW_APM_EVENTS_FLUSH_BATCH_SIZE'] = '8'
    ENV['SW_APM_TOKEN_BUCKET_CAPACITY'] = '9'
    ENV['SW_APM_TOKEN_BUCKET_RATE'] = '10'
    ENV['SW_APM_REPORTER_FILE_SINGLE'] = 'True'
    ENV['SW_APM_EC2_METADATA_TIMEOUT'] = '1234'
    ENV['SW_APM_PROXY'] = 'http://the.proxy:1234'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    options = SolarWindsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 23
    _(options[0]).must_equal 'string_4'
    _(options[1]).must_equal 2
    _(options[2]).must_equal 'string_5'
    _(options[3]).must_equal 5
    _(options[4]).must_equal 6
    _(options[5]).must_equal 7
    _(options[6]).must_equal 8
    _(options[7]).must_equal 'ssl'
    _(options[8]).must_equal 'string_2'
    _(options[9]).must_equal 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:test_app'
    _(options[10]).must_equal 'string_3'
    _(options[11]).must_equal 11
    _(options[12]).must_equal 3
    _(options[13]).must_equal 4
    _(options[14]).must_equal 9
    _(options[15]).must_equal 10
    _(options[16]).must_equal 1
    _(options[17]).must_equal 1234
    _(options[18]).must_equal 'http://the.proxy:1234'
    _(options[22]).must_equal 0
  end

  it 'reads config vars' do
    ENV.delete('SW_APM_GEM_TEST')
    ENV['SW_APM_REPORTER'] = 'ssl'

    ENV.delete('SW_APM_HOSTNAME_ALIAS')
    ENV.delete('SW_APM_DEBUG_LEVEL')
    ENV.delete('SW_APM_SERVICE_KEY')
    ENV.delete('SW_APM_EC2_METADATA_TIMEOUT')
    ENV.delete('SW_APM_PROXY')
    ENV.delete('')

    SolarWindsAPM::Config[:hostname_alias] = 'string_0'
    SolarWindsAPM::Config[:debug_level] = 0
    SolarWindsAPM::Config[:service_key] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:test_app'
    SolarWindsAPM::Config[:ec2_metadata_timeout] = 2345
    SolarWindsAPM::Config[:http_proxy] = 'http://the.proxy:7777'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    options = SolarWindsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 23

    _(options[0]).must_equal 'string_0'
    _(options[1]).must_equal 0
    _(options[9]).must_equal 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:test_app'
    _(options[17]).must_equal 2345
    _(options[18]).must_equal 'http://the.proxy:7777'
  end

  it 'env vars override config vars' do
    ENV.delete('SW_APM_GEM_TEST')
    ENV['SW_APM_REPORTER'] = 'ssl'

    ENV['SW_APM_HOSTNAME_ALIAS'] = 'string_0'
    ENV['SW_APM_DEBUG_LEVEL'] = '1'
    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:test_app'
    ENV['SW_APM_EC2_METADATA_TIMEOUT'] = '1212'
    ENV['SW_APM_PROXY'] = 'http://the.proxy:2222'

    SolarWindsAPM::Config[:hostname_alias] = 'string_2'
    SolarWindsAPM::Config[:debug_level] = 2
    SolarWindsAPM::Config[:service_key] = 'string_3'
    SolarWindsAPM::Config[:ec2_metadata_timeout] = 2323
    SolarWindsAPM::Config[:http_proxy] = 'http://the.proxy:7777'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    options = SolarWindsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 23

    _(options[0]).must_equal 'string_0'
    _(options[1]).must_equal 1
    _(options[9]).must_equal 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:test_app'
    _(options[17]).must_equal 1212
    _(options[18]).must_equal 'http://the.proxy:2222'
  end

  it 'checks for metric mode appoptics' do
    ENV.delete('SW_APM_COLLECTOR')
    ENV['SW_APM_COLLECTOR'] = 'collector.appoptics.com'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    options = SolarWindsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 23
    _(options[22]).must_equal 0
  end

  it 'checks for metric mode nighthack' do
    ENV.delete('SW_APM_COLLECTOR')
    ENV['SW_APM_COLLECTOR'] = 'collector.abc.bbc.solarwinds.com'
    
    SolarWindsAPM::OboeInitOptions.instance.re_init
    options = SolarWindsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 23
    _(options[22]).must_equal 1
  end

  it 'checks for metric mode default' do
    ENV.delete('SW_APM_COLLECTOR')
    ENV['SW_APM_COLLECTOR'] = 'www.google.ca'
    
    SolarWindsAPM::OboeInitOptions.instance.re_init
    options = SolarWindsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 23
    _(options[22]).must_equal 0
  end

  it 'checks the service_key for ssl' do
    ENV.delete('SW_APM_GEM_TEST')
    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = 'string_0'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:test_app'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
  end

  it 'returns true for the service_key check for other reporters' do
    ENV.delete('SW_APM_GEM_TEST')
    ENV['SW_APM_REPORTER'] = 'udp'
    ENV['SW_APM_SERVICE_KEY'] = 'string_0'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['SW_APM_REPORTER'] = 'file'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['SW_APM_REPORTER'] = 'null'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
  end

  it 'validates the service key' do
    ENV.delete('SW_APM_GEM_TEST')
    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = nil
    SolarWindsAPM::Config[:service_key] = nil

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    SolarWindsAPM::Config[:service_key] = '22222222-2222-2222-2222-222222222222:service'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    SolarWindsAPM::Config[:service_key] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    SolarWindsAPM::Config[:service_key] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    SolarWindsAPM::Config[:service_key] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:service'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['SW_APM_SERVICE_KEY'] = 'blabla'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = nil
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['SW_APM_SERVICE_KEY'] = '22222222-2222-2222-2222-222222222222:service'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:service'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
  end

  it 'removes invalid characters from the service name' do
    ENV.delete('SW_APM_GEM_TEST')
    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = 'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:service#####.:-_0'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
    _(SolarWindsAPM::OboeInitOptions.instance.service_name).must_equal 'service.:-_0'
  end

  it 'transforms the service name to lower case' do
    ENV.delete('SW_APM_GEM_TEST')
    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = 'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:SERVICE#####.:-_0'

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
    _(SolarWindsAPM::OboeInitOptions.instance.service_name).must_equal 'service.:-_0'
  end

  it 'shortens the service name to 255 characters' do
    ENV.delete('SW_APM_GEM_TEST')
    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = "f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:SERV#_#{'1234567890' * 26}"

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
    _(SolarWindsAPM::OboeInitOptions.instance.service_name).must_equal "serv_#{'1234567890' * 25}"
  end

  it 'replaces invalid ec2 metadata timeouts with the default' do
    ENV['SW_APM_EC2_METADATA_TIMEOUT'] = '-12'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.ec2_md_timeout).must_equal 1000

    ENV['SW_APM_EC2_METADATA_TIMEOUT'] = '3001'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.ec2_md_timeout).must_equal 1000

    ENV['SW_APM_EC2_METADATA_TIMEOUT'] = 'qoieurqopityeoritbweortmvoiu'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.ec2_md_timeout).must_equal 1000
  end

  it 'rejects invalid proxy strings' do
    ENV['SW_APM_PROXY'] = ''

    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.grpc_proxy).must_equal ''

    ENV['SW_APM_PROXY'] = 'qoieurqopityeoritbweortmvoiu'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.grpc_proxy).must_equal ''

    ENV['SW_APM_PROXY'] = 'https://sgdgsdg:4000'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.grpc_proxy).must_equal ''

    ENV['SW_APM_PROXY'] = 'http://sgdgsdg'
    SolarWindsAPM::OboeInitOptions.instance.re_init
    _(SolarWindsAPM::OboeInitOptions.instance.grpc_proxy).must_equal ''
  end
end
