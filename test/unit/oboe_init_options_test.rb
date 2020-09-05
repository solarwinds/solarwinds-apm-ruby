# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'OboeInitOptions' do

  before do
    @env = ENV.to_hash
    # lets suppress logging, because we will log a lot of errors when testing the service_key
    @log_level = AppOpticsAPM.logger.level
    AppOpticsAPM.logger.level = 6
  end

  after do
    @env.each { |k,v| ENV[k] = v }
    AppOpticsAPM::OboeInitOptions.instance.re_init
    AppOpticsAPM.logger.level = @log_level
  end

  it 'sets all options from ENV vars' do
    ENV.delete('APPOPTICS_GEM_TEST')

    ENV['APPOPTICS_SERVICE_KEY'] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:test_app'
    ENV['APPOPTICS_REPORTER'] = 'ssl'
    ENV['APPOPTICS_COLLECTOR'] = 'string_2'
    ENV['APPOPTICS_TRUSTEDPATH'] = 'string_3'
    ENV['APPOPTICS_HOSTNAME_ALIAS'] = 'string_4'
    ENV['APPOPTICS_BUFSIZE'] = '11'
    ENV['APPOPTICS_LOGFILE'] = 'string_5'
    ENV['APPOPTICS_DEBUG_LEVEL'] = '2'
    ENV['APPOPTICS_TRACE_METRICS'] = '3'
    ENV['APPOPTICS_HISTOGRAM_PRECISION'] = '4'
    ENV['APPOPTICS_MAX_TRANSACTIONS'] = '5'
    ENV['APPOPTICS_FLUSH_MAX_WAIT_TIME'] = '6'
    ENV['APPOPTICS_EVENTS_FLUSH_INTERVAL'] = '7'
    ENV['APPOPTICS_EVENTS_FLUSH_BATCH_SIZE'] = '8'
    ENV['APPOPTICS_TOKEN_BUCKET_CAPACITY'] = '9'
    ENV['APPOPTICS_TOKEN_BUCKET_RATE'] = '10'
    ENV['APPOPTICS_REPORTER_FILE_SINGLE'] = 'True'
    ENV['APPOPTICS_EC2_METADATA_TIMEOUT'] = '1234'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    options = AppOpticsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 19
    _(options[0]).must_equal 'string_4'
    _(options[1]).must_equal 2
    _(options[2]).must_equal 'string_5'
    _(options[3]).must_equal 5
    _(options[4]).must_equal 6
    _(options[5]).must_equal 7
    _(options[6]).must_equal 8
    _(options[7]).must_equal 'ssl'
    _(options[8]).must_equal 'string_2'
    _(options[9]).must_equal '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:test_app'
    _(options[10]).must_equal 'string_3'
    _(options[11]).must_equal 11
    _(options[12]).must_equal 3
    _(options[13]).must_equal 4
    _(options[14]).must_equal 9
    _(options[15]).must_equal 10
    _(options[16]).must_equal 1
    _(options[17]).must_equal 1234
    _(options[18]).must_equal ''
  end

  it 'reads config vars' do
    ENV.delete('APPOPTICS_GEM_TEST')
    ENV['APPOPTICS_REPORTER'] = 'ssl'

    ENV.delete('APPOPTICS_HOSTNAME_ALIAS')
    ENV.delete('APPOPTICS_DEBUG_LEVEL')
    ENV.delete('APPOPTICS_SERVICE_KEY')
    ENV.delete('APPOPTICS_EC2_METADATA_TIMEOUT')

    AppOpticsAPM::Config[:hostname_alias] = 'string_0'
    AppOpticsAPM::Config[:debug_level] = 0
    AppOpticsAPM::Config[:service_key] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:test_app'
    AppOpticsAPM::Config[:ec2_metadata_timeout] = 2345

    AppOpticsAPM::OboeInitOptions.instance.re_init
    options = AppOpticsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 19

    _(options[0]).must_equal 'string_0'
    _(options[1]).must_equal 0
    _(options[9]).must_equal '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:test_app'
    _(options[17]).must_equal 2345
  end

  it 'env vars override config vars' do
    ENV.delete('APPOPTICS_GEM_TEST')
    ENV['APPOPTICS_REPORTER'] = 'ssl'

    ENV['APPOPTICS_HOSTNAME_ALIAS'] = 'string_0'
    ENV['APPOPTICS_DEBUG_LEVEL'] = '1'
    ENV['APPOPTICS_SERVICE_KEY'] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:test_app'
    ENV['APPOPTICS_EC2_METADATA_TIMEOUT'] = '1212'

    AppOpticsAPM::Config[:hostname_alias] = 'string_2'
    AppOpticsAPM::Config[:debug_level] = 2
    AppOpticsAPM::Config[:service_key] = 'string_3'
    AppOpticsAPM::Config[:ec2_metadata_timeout] = 2323

    AppOpticsAPM::OboeInitOptions.instance.re_init
    options = AppOpticsAPM::OboeInitOptions.instance.array_for_oboe

    _(options.size).must_equal 19

    _(options[0]).must_equal 'string_0'
    _(options[1]).must_equal 1
    _(options[9]).must_equal '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:test_app'
    _(options[17]).must_equal 1212
  end

  it 'checks the service_key for ssl' do
    ENV.delete('APPOPTICS_GEM_TEST')
    ENV['APPOPTICS_REPORTER'] = 'ssl'
    ENV['APPOPTICS_SERVICE_KEY'] = 'string_0'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['APPOPTICS_SERVICE_KEY'] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:test_app'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['APPOPTICS_SERVICE_KEY'] = 'f7B-kZXtk1sxaJGkv-wew12Y6Yts3KJJ0KuBs-p1111111111KFVPRv0o8keDro9QbKioW4:test_app'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
  end

  it 'returns true for the service_key check for other reporters' do
    ENV.delete('APPOPTICS_GEM_TEST')
    ENV['APPOPTICS_REPORTER'] = 'udp'
    ENV['APPOPTICS_SERVICE_KEY'] = 'string_0'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['APPOPTICS_REPORTER'] = 'file'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['APPOPTICS_REPORTER'] = 'null'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
  end

  it 'validates the service key' do
    ENV.delete('APPOPTICS_GEM_TEST')
    ENV['APPOPTICS_REPORTER'] = 'ssl'
    ENV['APPOPTICS_SERVICE_KEY'] = nil
    AppOpticsAPM::Config[:service_key] = nil

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    AppOpticsAPM::Config[:service_key] = '22222222-2222-2222-2222-222222222222:service'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    AppOpticsAPM::Config[:service_key] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    AppOpticsAPM::Config[:service_key] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    AppOpticsAPM::Config[:service_key] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:service'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    AppOpticsAPM::Config[:service_key] = 'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    AppOpticsAPM::Config[:service_key] = 'f7B-kZXtk1sxaJGkv-wew1255555555555555555555akVIptKFVPRv0o8keDro9QbKioW4:'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    AppOpticsAPM::Config[:service_key] = 'f7B-kZXtk1sxaJGkv-wew12Y6666666666666666666akVIptKFVPRv0o8keDro9QbKioW4:service'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['APPOPTICS_SERVICE_KEY'] = 'blabla'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['APPOPTICS_SERVICE_KEY'] = nil
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['APPOPTICS_SERVICE_KEY'] = '22222222-2222-2222-2222-222222222222:service'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['APPOPTICS_SERVICE_KEY'] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['APPOPTICS_SERVICE_KEY'] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['APPOPTICS_SERVICE_KEY'] = '2895f613c0f452d6bc5dc000008f6754062689e224ec245926be520be0c00000:service'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true

    ENV['APPOPTICS_SERVICE_KEY'] = 'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['APPOPTICS_SERVICE_KEY'] = 'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal false

    ENV['APPOPTICS_SERVICE_KEY'] = 'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:service'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
  end

  it 'removes invalid characters from the service name' do
    ENV.delete('APPOPTICS_GEM_TEST')
    ENV['APPOPTICS_REPORTER'] = 'ssl'
    ENV['APPOPTICS_SERVICE_KEY'] = 'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:service#####.:-_0'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
    _(AppOpticsAPM::OboeInitOptions.instance.service_name).must_equal 'service.:-_0'
  end

  it 'transforms the service name to lower case' do
    ENV.delete('APPOPTICS_GEM_TEST')
    ENV['APPOPTICS_REPORTER'] = 'ssl'
    ENV['APPOPTICS_SERVICE_KEY'] = 'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:SERVICE#####.:-_0'

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
    _(AppOpticsAPM::OboeInitOptions.instance.service_name).must_equal 'service.:-_0'
  end

  it 'shortens the service name to 255 characters' do
    ENV.delete('APPOPTICS_GEM_TEST')
    ENV['APPOPTICS_REPORTER'] = 'ssl'
    ENV['APPOPTICS_SERVICE_KEY'] = "f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:SERV#_#{'1234567890' * 26}"

    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.service_key_ok?).must_equal true
    _(AppOpticsAPM::OboeInitOptions.instance.service_name).must_equal "serv_#{'1234567890' * 25}"
  end

  it 'replaces invalid ec2 metadata timeouts with the default' do
    ENV.delete('APPOPTICS_EC2_METADATA_TIMEOUT')

    ENV['APPOPTICS_EC2_METADATA_TIMEOUT'] = '-12'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.ec2_md_timeout).must_equal 1000

    ENV['APPOPTICS_EC2_METADATA_TIMEOUT'] = '3001'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.ec2_md_timeout).must_equal 1000


    ENV['APPOPTICS_EC2_METADATA_TIMEOUT'] = 'qoieurqopityeoritbweortmvoiu'
    AppOpticsAPM::OboeInitOptions.instance.re_init
    _(AppOpticsAPM::OboeInitOptions.instance.ec2_md_timeout).must_equal 1000
  end
end
