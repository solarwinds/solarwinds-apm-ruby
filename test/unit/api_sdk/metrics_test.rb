# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe AppOpticsAPM::API::Metrics do
  describe 'send_metrics' do

    it 'should send the correct duration and create a transaction name' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::Span.expects(:createSpan).with('custom-test', nil, 0)
        AppOpticsAPM::API.send_metrics('test') {}
      end
    end

    it 'should set the created transaction name and return the result from the block' do
      result = AppOpticsAPM::API.send_metrics('test') { 42 }

      assert_equal 'custom-test', AppOpticsAPM::SDK.get_transaction_name
      assert_equal 42, result
    end

    it 'should use the transaction name from the params' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::Span.expects(:createSpan).with('this_name', nil, 0)
        AppOpticsAPM::SDK.set_transaction_name('trying_to_confuse_you')
        AppOpticsAPM::API.send_metrics('test', :TransactionName => 'this_name') {}
      end
    end

    it 'should set the transaction name from the params' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::SDK.set_transaction_name('trying_to_confuse_you')
        AppOpticsAPM::API.send_metrics('test', :TransactionName => 'this_name') {}
      end

      assert_equal 'this_name', AppOpticsAPM::SDK.get_transaction_name
    end

  end
end
