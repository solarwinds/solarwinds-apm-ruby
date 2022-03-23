# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe SolarWindsAPM::API::Metrics do
  describe 'send_metrics' do
    before do
      SolarWindsAPM.transaction_name = nil
    end

    it 'should send the correct duration and create a transaction name' do
      Time.stub(:now, Time.at(0)) do
        SolarWindsAPM::Span.expects(:createSpan).with('custom-test', nil, 0, 0)
        SolarWindsAPM::API.send_metrics('test', {}) {}
      end
    end

    it 'should set the created transaction name and return the result from the block' do
      opts = {}
      result = SolarWindsAPM::API.send_metrics('test', opts) { 42 }

      assert_equal 'custom-test', opts[:TransactionName]
      assert_equal 42, result
    end

    it 'should override the transaction name from the params for createSpan' do
      Time.stub(:now, Time.at(0)) do
        SolarWindsAPM::Span.expects(:createSpan).with('this_name', nil, 0, 0)

        SolarWindsAPM::SDK.set_transaction_name('this_name')
        # :TransactionName should not even be in there!!!
        SolarWindsAPM::API.send_metrics('test', :TransactionName => 'trying_to_confuse_you') {}
      end
    end

    it 'should override the transaction name from the params' do
      # :TransactionName should not even be in there!!!
      opts = { :TransactionName => 'trying_to_confuse_you' }

      SolarWindsAPM::SDK.set_transaction_name('this_name')
      SolarWindsAPM::API.send_metrics('test', opts) {}

      assert_equal 'this_name', opts[:TransactionName]
    end

  end
end
