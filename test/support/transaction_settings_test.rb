# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe 'TransactionSettingsTest' do
  before do
    @tracing_mode = AppOpticsAPM::Config[:tracing_mode]
    @sample_rate = AppOpticsAPM::Config[:sample_rate]
    @config_map = AppOpticsAPM::Util.deep_dup(AppOpticsAPM::Config[:transaction_settings])
    @config_url_disabled = AppOpticsAPM::Config[:url_disabled_regexps]
    @config_url_enabled = AppOpticsAPM::Config[:url_enabled_regexps]
  end

  after do
    AppOpticsAPM::Config[:transaction_settings] = AppOpticsAPM::Util.deep_dup(@config_map)
    AppOpticsAPM::Config[:url_enabled_regexps] = @config_url_enabled
    AppOpticsAPM::Config[:url_disabled_regexps] = @config_url_disabled
    AppOpticsAPM::Config[:tracing_mode] = @tracing_mode
    AppOpticsAPM::Config[:sample_rate] = @sample_rate
  end

  describe 'AppOpticsAPM::TransactionSettings' do

    it 'the default leads to no :url_disabled_regexps' do
      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it " creates no url regexps if :transaction_settings doesn't have a :url key" do
      AppOpticsAPM::Config[:url_enabled_regexps] = Regexp.new(/.*lobster.*/)
      AppOpticsAPM::Config[:url_disabled_regexps] = Regexp.new(/.*lobster.*/)
      AppOpticsAPM::Config[:transaction_settings] = 'LA VIE EST BELLE'

      _(AppOpticsAPM::Config[:url_enabled_regexps]).must_be_nil
      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it 'does not compile an empty regexp' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ regexp: '' },
                                                            { regexp: // }] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it 'does not compile a faulty regexp' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ regexp: 123 }] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it 'compiles a regexp' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ regexp: /.*lobster.*/ }] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/.*lobster.*/)]
    end

    it 'combines multiple regexps' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [
        { regexp: /.*lobster.*/ },
        { regexp: /.*shrimp*/ }
      ] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/.*lobster.*/),
                                                              Regexp.new(/.*shrimp*/)]
    end

    it 'ignores faulty regexps' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [
        { regexp: /.*lobster.*/ },
        { regexp: 123 },
        { regexp: /.*shrimp*/ }
      ] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/.*lobster.*/),
                                                              Regexp.new(/.*shrimp*/)]
    end

    it 'applies url_opts' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ regexp: 'lobster',
                                                              opts: Regexp::IGNORECASE }] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new('lobster', Regexp::IGNORECASE)]
    end

    it 'ignores url_opts that are incorrect' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ regexp: 'lobster',
                                                              opts: 123456 }] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/lobster/)]
    end

    it 'applies a mixtures of url_opts' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [
        { regexp: 'lobster', opts: Regexp::EXTENDED },
        { regexp: 123, opts: Regexp::IGNORECASE },
        { regexp: 'shrimp', opts: Regexp::IGNORECASE }
      ] }
      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/lobster/x),
                                                              Regexp.new(/shrimp/i)]
    end

    it 'converts a list of extensions into a regex' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ extensions: %w[.just a test] }] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/(\.just|a|test)(\?.+){0,1}$/)]
    end

    it 'ignores empty extensions lists' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ extensions: [] }] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it 'ignores non-string elements in extensions' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ extensions: ['.just', nil, 'a', 123, 'test'] }] }

      _(AppOpticsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/(\.just|a|test)(\?.+){0,1}$/)]
    end

    it 'combines regexps and extensions' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ extensions: %w[.just a test] },
                                                            { regexp: /.*lobster.*/ },
                                                            { regexp: 123 },
                                                            { regexp: /.*shrimp*/ }
      ] }

      _(AppOpticsAPM::TransactionSettings.new('test').do_sample).must_equal false
      _(AppOpticsAPM::TransactionSettings.new('lobster').do_sample).must_equal false
      _(AppOpticsAPM::TransactionSettings.new('bla/bla/shrimp?number=1').do_sample).must_equal false
      _(AppOpticsAPM::TransactionSettings.new('123').do_sample).must_equal true
      _(AppOpticsAPM::TransactionSettings.new('').do_sample).must_equal true
    end

    it 'separates enabled and disabled settings' do
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ extensions: %w[.just a test] },
                                                            { regexp: /.*lobster.*/ },
                                                            { regexp: 123, tracing: :enabled },
                                                            { regexp: /.*shrimp*/, tracing: :enabled }
      ] }

      _(AppOpticsAPM::TransactionSettings.new('test').do_sample).must_equal false
      _(AppOpticsAPM::TransactionSettings.new('lobster').do_sample).must_equal false
      _(AppOpticsAPM::TransactionSettings.new('bla/bla/shrimp?number=1').do_sample).must_equal true
      _(AppOpticsAPM::TransactionSettings.new('123').do_sample).must_equal true
      _(AppOpticsAPM::TransactionSettings.new('').do_sample).must_equal true
    end

    it 'samples enabled patterns, when globally disabled' do
      AppOpticsAPM::Config[:tracing_mode] = :disabled
      AppOpticsAPM::Config[:transaction_settings] = { url: [{ extensions: %w[.just a test] },
                                                            { regexp: /.*lobster.*/ },
                                                            { regexp: 123, tracing: :enabled },
                                                            { regexp: /.*shrimp*/, tracing: :enabled }
      ] }

      _(AppOpticsAPM::TransactionSettings.new('test').do_sample).must_equal false
      _(AppOpticsAPM::TransactionSettings.new('lobster').do_sample).must_equal false
      _(AppOpticsAPM::TransactionSettings.new('bla/bla/shrimp?number=1').do_sample).must_equal true
      _(AppOpticsAPM::TransactionSettings.new('123').do_sample).must_equal false
      _(AppOpticsAPM::TransactionSettings.new('').do_sample).must_equal false
    end

    it 'sends the sample_rate and tracing_mode' do
      AppOpticsAPM::Config[:tracing_mode] = :disabled
      AppOpticsAPM::Config[:sample_rate] = 123456
      AppOpticsAPM::Context.expects(:getDecisions).with('', AO_TRACING_DISABLED, 123456).returns([0,0,0,0,0,0,0,0,'','',0]).once

      AppOpticsAPM::TransactionSettings.new('')
    end
  end
end
