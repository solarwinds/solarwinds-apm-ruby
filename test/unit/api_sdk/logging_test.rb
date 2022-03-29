# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe SolarWindsAPM::API::Logging do
  describe 'log_start' do
    before do
      # SolarWindsAPM::Context.clear
    end

    it 'does not log if solarwinds_apm is not loaded' do
      SolarWindsAPM.expects(:loaded).returns(false)
      SolarWindsAPM::API.expects(:log_event).never

      SolarWindsAPM::API.log_start(:test_no_ao)
      refute SolarWindsAPM::Context.isValid
    end

    it 'logs if there is a sampling context' do
      md = SolarWindsAPM::Metadata.makeRandom(true)
      SolarWindsAPM::Context.set(md)

      SolarWindsAPM::API.expects(:log_event)

      SolarWindsAPM::API.log_start(:test_sampling_context)

      assert SolarWindsAPM.tracing?
    end

    it 'does not log if there is a non-sampling context ' do
      md = SolarWindsAPM::Metadata.makeRandom(false)
      SolarWindsAPM::Context.set(md)

      SolarWindsAPM::API.expects(:log_event).never

      SolarWindsAPM::API.log_start(:test_non_sampling_context)

      refute SolarWindsAPM.tracing?
    end

    it 'creates settings if none are provided' do
      settings = SolarWindsAPM::TransactionSettings.new
      SolarWindsAPM::TransactionSettings.expects(:new).returns(settings)

      SolarWindsAPM::API.log_start(:test_settings)
    end

    it 'creates a context' do
      SolarWindsAPM::API.log_start(:test_create_context)
      assert SolarWindsAPM::Context.isValid
    end

    it 'logs and creates a sampling context if do sample' do
      settings = SolarWindsAPM::TransactionSettings.new
      settings.do_sample = true
      SolarWindsAPM::TransactionSettings.expects(:new).returns(settings)
      SolarWindsAPM::API.expects(:log_event)

      SolarWindsAPM::API.log_start(:test_create_sampling_context)
      assert SolarWindsAPM.tracing?
    end

    it 'does not log and creates a non-sampling context if NOT do sample' do
      settings = SolarWindsAPM::TransactionSettings.new
      settings.do_sample = false
      SolarWindsAPM::TransactionSettings.expects(:new).returns(settings)
      SolarWindsAPM::API.expects(:log_event).never

      SolarWindsAPM::API.log_start(:test_create_sampling_context)
      refute SolarWindsAPM.tracing?
    end
  end

  describe "when there is a non-sampling context" do
    before do
      md = SolarWindsAPM::Metadata.makeRandom(false)
      SolarWindsAPM::Context.set(md)
    end

    it "log should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log(:test, 'test_label')
    end

    it "log_exception should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_exception(:test, StandardError.new('no worries - testing error'))
    end

    it "log_end should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_end(:test)
    end

    it "log_entry should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_entry(:test)
    end

    it "log_info should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_info(:test)
    end

    it "log_exit should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_exit(:test)
    end
  end

  describe "when we are sampling" do
    before do
      md = SolarWindsAPM::Metadata.makeRandom(true)
      SolarWindsAPM::Context.set(md)
    end

    it "log should log an event" do
      SolarWindsAPM::API.expects(:log_event)
      SolarWindsAPM::API.log(:test, 'test_label')
    end

    it "log_exception should log an event" do
      msg = 'no worries - testing error'
      SolarWindsAPM::API.expects(:log).with(:test, :error,
                                           { Spec: 'error',
                                             ErrorMsg: msg,
                                             ErrorClass: 'StandardError' }).once
      SolarWindsAPM::API.log_exception(:test, StandardError.new(msg))
    end

    it "log_exception should only log an exception once" do
      exception = StandardError.new('no worries - testing error')
      SolarWindsAPM::API.expects(:log).once

      SolarWindsAPM::API.log_exception(:test_0, exception)
      SolarWindsAPM::API.log_exception(:test_1, exception)
    end

    it "log_end should log an event" do
      SolarWindsAPM::API.expects(:log_event)
      SolarWindsAPM::API.log_end(:test)
    end

    it "log_entry should log an event" do
      SolarWindsAPM::API.expects(:log_event)
      SolarWindsAPM::API.log_entry(:test)
    end

    it "log_info should log an event" do
      SolarWindsAPM::API.expects(:log_event)
      SolarWindsAPM::API.log_info(:test)
    end

    it "log_exit should log an event" do
      SolarWindsAPM::API.expects(:log_event)
      SolarWindsAPM::API.log_exit(:test)
    end
  end

  describe "when there is no context" do
    before do
      # SolarWindsAPM::Context.clear
    end

    it "log should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log(:test, 'test_label')
    end

    it "log_exception should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_exception(:test, StandardError.new('no worries - testing error'))
    end

    it "log_end should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_end(:test)
    end

    it "log_entry should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_entry(:test)
    end

    it "log_info should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_info(:test)
    end

    it "log_exit should not log an event" do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.log_exit(:test)
    end
  end

  describe "when we use the op parameter" do
    before do
      md = SolarWindsAPM::Metadata.makeRandom(true)
      SolarWindsAPM::Context.set(md)
      SolarWindsAPM.layer_op = nil
    end

    it "should add and remove the layer_op (same op)" do
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)
      assert_equal [:test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)

      assert_empty SolarWindsAPM.layer_op
    end

    it "should add and remove the layer_op (different ops)" do
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test_2)
      assert_equal [:test, :test_2], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test_2)
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test_3)
      assert_equal [:test, :test_3], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test_3)
      assert_equal [:test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)

      assert_empty SolarWindsAPM.layer_op
    end

    it "should stack ops even if they repeat" do
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test_2)
      assert_equal [:test, :test_2], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test_2, :test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)
      assert_equal [:test, :test_2], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test_2)
      assert_equal [:test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)

      assert_empty SolarWindsAPM.layer_op
    end

    it "only removes the last op when it matches" do
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test_2)
      assert_equal [:test, :test_2], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test_2, :test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)
      SolarWindsAPM::API.log_exit(:test, {}, :test)
      SolarWindsAPM::API.log_exit(:test, {}, :test)
      assert_equal [:test, :test_2], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test_2)
      assert_equal [:test], SolarWindsAPM.layer_op
      SolarWindsAPM::API.log_exit(:test, {}, :test)

      assert_empty SolarWindsAPM.layer_op
    end

    it "does not log an event when the last op matches" do
      SolarWindsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).times 3
      # we create an exit if the layer op does not match and also log a warning
      SolarWindsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).times 5
      SolarWindsAPM.logger.expects(:warn).times 2

      SolarWindsAPM::API.log_entry(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test_2)
      SolarWindsAPM::API.log_entry(:test, {}, :test_2)
      SolarWindsAPM::API.log_entry(:test, {}, :test)
      SolarWindsAPM::API.log_entry(:test, {}, :test)

      SolarWindsAPM::API.log_exit(:test, {}, :test)

      SolarWindsAPM::API.log_exit(:test, {}, :test)
      SolarWindsAPM::API.log_exit(:test, {}, :test_2)

      # exit that does not match an entry op => SolarWindsAPM.logger.warn
      SolarWindsAPM::API.log_exit(:test, {}, :test)

      SolarWindsAPM::API.log_exit(:test, {}, :test_2)
      SolarWindsAPM::API.log_exit(:test, {}, :test)

      # another extra exit that does not match an entry op => SolarWindsAPM.logger.info
      SolarWindsAPM::API.log_exit(:test, {}, :test)
    end
  end
end
