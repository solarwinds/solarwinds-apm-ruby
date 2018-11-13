# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe AppOpticsAPM::SDK do
  describe 'CustomMetrics' do
    describe 'Increment' do
      it 'should do increment with one arg' do
        refute_raises do
          AppOpticsAPM::SDK.increment_metric('test_name')
        end
      end

      it 'should do increment with all args' do
        refute_raises do
          AppOpticsAPM::SDK.increment_metric('test_name', 1, { 'alfa' => 1, 'beta' => 2 } )
        end
      end

      it 'should handle wrong tags gracefully for increment' do
        refute_raises do
          AppOpticsAPM::SDK.increment_metric(:test_name, 2, true, 7.7)
        end
      end

      it 'should call c-lib increment with the correct default args' do
        Oboe_metal::CustomMetrics.expects(:increment).with('test_name', 1, 0, nil, is_a(AppOpticsAPM::MetricTags), 0)
        AppOpticsAPM::SDK.increment_metric('test_name')
      end

      it 'should call c-lib increment with the correct given args' do
        AppOpticsAPM::CustomMetrics.expects(:increment).with('test_name', 2, 1, nil, is_a(AppOpticsAPM::MetricTags), 2)
        AppOpticsAPM::SDK.increment_metric('test_name', 2, true, { 'alfa' => 1, 'beta' => 2 } )
      end
    end

    describe 'Summary' do
      it 'should do summary with two args' do
        refute_raises do
          AppOpticsAPM::SDK.summary_metric('test_name', 7.7)
        end
      end

      it 'should summary with all args' do
        refute_raises do
          AppOpticsAPM::SDK.summary_metric('test_name', 7.7, 1, { 'alfa' => 1, 'beta' => 2 } )
        end
      end

      it 'should handle wrong arg types gracefully' do
        refute_raises do
          AppOpticsAPM::SDK.summary_metric(:test_name, 15.4, 2, true, 7.7)
        end
      end

      it 'should call summary with the correct default args' do
        Oboe_metal::CustomMetrics.expects(:summary).with('test_name', 7.7, 1, 0, nil, is_a(AppOpticsAPM::MetricTags), 0)
        AppOpticsAPM::SDK.summary_metric('test_name', 7.7)
      end

      it 'should call summary with the correct given args' do
        AppOpticsAPM::CustomMetrics.expects(:summary).with('test_name', 7.7, 2, 1, nil, is_a(AppOpticsAPM::MetricTags), 2)
        AppOpticsAPM::SDK.summary_metric('test_name', 7.7, 2, true, { 'alfa' => 1, 'beta' => 2 } )
      end
    end
  end
end
