# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe AppOpticsAPM::API do
  describe 'start_trace' do

    before do
      clear_all_traces
    end

    it 'should return the result and the xtrace' do
      result, xtrace = AppOpticsAPM::API.start_trace('test') { 42 }

      assert_equal 42, result
      assert_match /^2B[0-9A-F]*01$/, xtrace

      traces = get_all_traces
      assert_equal traces.last['X-Trace'], xtrace
    end
  end
end
