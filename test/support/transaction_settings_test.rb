# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe 'TransactionSettingsTest' do
  before do
    @tracing_mode = SolarWindsAPM::Config[:tracing_mode]
    @sample_rate = SolarWindsAPM::Config[:sample_rate]
    @config_map = SolarWindsAPM::Util.deep_dup(SolarWindsAPM::Config[:transaction_settings])
    @config_url_disabled = SolarWindsAPM::Config[:url_disabled_regexps]
    @config_url_enabled = SolarWindsAPM::Config[:url_enabled_regexps]
  end

  after do
    SolarWindsAPM::Config[:transaction_settings] = SolarWindsAPM::Util.deep_dup(@config_map)
    SolarWindsAPM::Config[:url_enabled_regexps] = @config_url_enabled
    SolarWindsAPM::Config[:url_disabled_regexps] = @config_url_disabled
    SolarWindsAPM::Config[:tracing_mode] = @tracing_mode
    SolarWindsAPM::Config[:sample_rate] = @sample_rate
  end

  describe 'SolarWindsAPM::TransactionSettings' do

    it 'the default leads to no :url_disabled_regexps' do
      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it " creates no url regexps if :transaction_settings doesn't have a :url key" do
      SolarWindsAPM::Config[:url_enabled_regexps] = Regexp.new(/.*lobster.*/)
      SolarWindsAPM::Config[:url_disabled_regexps] = Regexp.new(/.*lobster.*/)
      SolarWindsAPM::Config[:transaction_settings] = 'LA VIE EST BELLE'

      _(SolarWindsAPM::Config[:url_enabled_regexps]).must_be_nil
      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it 'does not compile an empty regexp' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ regexp: '' },
                                                            { regexp: // }] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it 'does not compile a faulty regexp' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ regexp: 123 }] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it 'compiles a regexp' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ regexp: /.*lobster.*/ }] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/.*lobster.*/)]
    end

    it 'combines multiple regexps' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [
        { regexp: /.*lobster.*/ },
        { regexp: /.*shrimp*/ }
      ] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/.*lobster.*/),
                                                                 Regexp.new(/.*shrimp*/)]
    end

    it 'ignores faulty regexps' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [
        { regexp: /.*lobster.*/ },
        { regexp: 123 },
        { regexp: /.*shrimp*/ }
      ] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/.*lobster.*/),
                                                                 Regexp.new(/.*shrimp*/)]
    end

    it 'applies url_opts' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ regexp: 'lobster',
                                                              opts: Regexp::IGNORECASE }] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new('lobster', Regexp::IGNORECASE)]
    end

    it 'ignores url_opts that are incorrect' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ regexp: 'lobster',
                                                              opts: 123456 }] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/lobster/)]
    end

    it 'applies a mixtures of url_opts' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [
        { regexp: 'lobster', opts: Regexp::EXTENDED },
        { regexp: 123, opts: Regexp::IGNORECASE },
        { regexp: 'shrimp', opts: Regexp::IGNORECASE }
      ] }
      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/lobster/x),
                                                                 Regexp.new(/shrimp/i)]
    end

    it 'converts a list of extensions into a regex' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ extensions: %w[.just a test] }] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/(\.just|a|test)(\?.+){0,1}$/)]
    end

    it 'ignores empty extensions lists' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ extensions: [] }] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_be_nil
    end

    it 'ignores non-string elements in extensions' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ extensions: ['.just', nil, 'a', 123, 'test'] }] }

      _(SolarWindsAPM::Config[:url_disabled_regexps]).must_equal [Regexp.new(/(\.just|a|test)(\?.+){0,1}$/)]
    end

    it 'combines regexps and extensions' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ extensions: %w[.just a test] },
                                                            { regexp: /.*lobster.*/ },
                                                            { regexp: 123 },
                                                            { regexp: /.*shrimp*/ }
      ] }

      _(SolarWindsAPM::TransactionSettings.new('test').do_sample).must_equal false
      _(SolarWindsAPM::TransactionSettings.new('lobster').do_sample).must_equal false
      _(SolarWindsAPM::TransactionSettings.new('bla/bla/shrimp?number=1').do_sample).must_equal false
      _(SolarWindsAPM::TransactionSettings.new('123').do_sample).must_equal true
      _(SolarWindsAPM::TransactionSettings.new('').do_sample).must_equal true
    end

    it 'separates enabled and disabled settings' do
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ extensions: %w[.just a test] },
                                                            { regexp: /.*lobster.*/ },
                                                            { regexp: 123, tracing: :enabled },
                                                            { regexp: /.*shrimp*/, tracing: :enabled }
      ] }

      _(SolarWindsAPM::TransactionSettings.new('test').do_sample).must_equal false
      _(SolarWindsAPM::TransactionSettings.new('lobster').do_sample).must_equal false
      _(SolarWindsAPM::TransactionSettings.new('bla/bla/shrimp?number=1').do_sample).must_equal true
      _(SolarWindsAPM::TransactionSettings.new('123').do_sample).must_equal true
      _(SolarWindsAPM::TransactionSettings.new('').do_sample).must_equal true
    end

    it 'samples enabled patterns, when globally disabled' do
      SolarWindsAPM::Config[:tracing_mode] = :disabled
      SolarWindsAPM::Config[:transaction_settings] = { url: [{ extensions: %w[.just a test] },
                                                            { regexp: /.*lobster.*/ },
                                                            { regexp: 123, tracing: :enabled },
                                                            { regexp: /.*shrimp*/, tracing: :enabled }
      ] }

      _(SolarWindsAPM::TransactionSettings.new('test').do_sample).must_equal false
      _(SolarWindsAPM::TransactionSettings.new('lobster').do_sample).must_equal false
      _(SolarWindsAPM::TransactionSettings.new('bla/bla/shrimp?number=1').do_sample).must_equal true
      _(SolarWindsAPM::TransactionSettings.new('123').do_sample).must_equal false
      _(SolarWindsAPM::TransactionSettings.new('').do_sample).must_equal false
    end

    it 'sends the sample_rate and tracing_mode' do
      SolarWindsAPM::Config[:tracing_mode] = :disabled
      SolarWindsAPM::Config[:sample_rate] = 123456
      SolarWindsAPM::Context.expects(:getDecisions).with(nil, nil, AO_TRACING_DISABLED, 123456).returns([0, 0, 0, 0, 0, 0, 0, 0, '', '', 0]).once

      SolarWindsAPM::TransactionSettings.new('')
    end
  end
end
