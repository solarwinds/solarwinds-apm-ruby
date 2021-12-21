# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe 'XTraceOptionsTest' do

  describe 'initialize' do

    it 'has defaults' do
      headers = ''

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.trigger_trace).must_equal false
      _(options.custom_kvs).must_be_instance_of Hash
      _(options.custom_kvs).must_be_empty
      _(options.ignored).must_be_instance_of Array
      _(options.ignored).must_be_empty
      _(options.sw_keys).must_be_nil
    end

    it 'processes a correctly formatted string' do
      headers =
        'trigger-trace;custom-something=value_thing; custom-OtherThing=other val;sw-keys=029734wr70:9wqj21,0d9j1'

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.trigger_trace).must_equal true
      _(options.custom_kvs['custom-OtherThing']).must_equal 'other val'
      _(options.custom_kvs['custom-something']).must_equal 'value_thing'
      _(options.sw_keys).must_equal '029734wr70:9wqj21,0d9j1'
    end

    it 'removes leading/trailing spaces' do
      headers =
        'custom-something=value; custom-OtherThing = other val ;sw-keys=029734wr70:9wqj21,0d9j1'

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.trigger_trace).must_equal false
      _(options.custom_kvs['custom-OtherThing']).must_equal 'other val'
      _(options.custom_kvs['custom-something']).must_equal 'value'
      _(options.sw_keys).must_equal '029734wr70:9wqj21,0d9j1'
    end

    it 'reports and logs ignored options' do
      headers = %w(what_is_this=value_thing
                   and_that=otherval
                   whoot).join(';')

      AppOpticsAPM.logger.expects(:info).once

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.ignored.sort).must_equal %w(what_is_this whoot and_that).sort
    end

    it 'ignores and logs trigger_trace with a value' do
      headers = %w(trigger_trace=1
                   custom-something=value_thing).join(';')

      AppOpticsAPM.logger.expects(:info).once

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.ignored).must_equal ['trigger_trace']
    end

    it 'keeps the value of the first repeated key' do
      headers = %w(trigger-trace
                   custom-something=keep_this_otherval
                   sw-keys=keep_this
                   sw-keys=029734wr70:9wqj21,0d9j1
                   custom-something=otherval).join(';')

      AppOpticsAPM.logger.expects(:info).twice

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.sw_keys).must_equal 'keep_this'
      _(options.custom_kvs['custom-something']).must_equal 'keep_this_otherval'
    end

    it 'keeps the value including "="' do
      headers =
        'trigger-trace;custom-something=value_thing=4;custom-OtherThing=other val'

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.custom_kvs['custom-something']).must_equal 'value_thing=4'
    end

    it 'tries best with ";" inside value, reports and logs bad key' do
      headers = "custom-foo='bar;bar';custom-bar=foo;"

      AppOpticsAPM.logger.expects(:info).once

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.custom_kvs['custom-foo']).must_equal "'bar"
      _(options.ignored).must_equal ["bar'"]
    end

    it 'does its best with a badly formatted header with empty key' do
      headers = %w(;trigger-trace
                   custom-something=value_thing).join(';')
      headers << ';sw-keys=029734wr70:9wqj21,0d9j1;1;;;2;3;4;5;=abc=and_now?;='

      AppOpticsAPM.logger.expects(:info).once

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.trigger_trace).must_equal true
      _(options.sw_keys).must_equal '029734wr70:9wqj21,0d9j1'
      _(options.custom_kvs['custom-something']).must_equal 'value_thing'
      _(options.ignored.sort).must_equal ["1", "2", "3", "4", "5", "", ""].sort
    end

    it 'ignores sequential ";;;"' do
      headers = 'custom-something=value_thing;sw-keys=02973r70;;;;custom-key=val'

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.custom_kvs['custom-something']).must_equal 'value_thing'
      _(options.custom_kvs['custom-key']).must_equal 'val'
      _(options.sw_keys).must_equal '02973r70'
    end

    it 'doesn\'t allow spaces in keys' do
      headers = 'trigger-trace;custom- something=value_thing;sw-keys=02973r70;;;;custom-k ey=val;custom-goodkey=good'

      AppOpticsAPM.logger.expects(:info).once

      options = AppOpticsAPM::XTraceOptions.new(headers)

      _(options.custom_kvs['custom-goodkey']).must_equal 'good'
      _(options.sw_keys).must_equal '02973r70'
      _(options.ignored.sort).must_equal ["custom- something", "custom-k ey"].sort
    end
  end
end