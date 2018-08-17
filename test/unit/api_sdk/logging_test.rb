# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe AppOpticsAPM::API::Logging do
  describe "when there is no xtrace" do
    before do
      AppOpticsAPM::Context.clear
    end

    it "log should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log(:test, 'test_label')
    end

    it "log_exception should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_exception(:test, StandardError.new('no worries - testing error'))
    end

    it "log_end should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_end(:test)
    end

    it "log_entry should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_entry(:test)
    end

    it "log_info should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_info(:test)
    end

    it "log_exit should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_exit(:test)
    end

    it "log_multi_exit should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_multi_exit(:test, [])
    end
  end

  describe "when we are not sampling" do
    before do
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA00')
    end

    it "log should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log(:test, 'test_label')
    end

    it "log_exception should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_exception(:test, StandardError.new('no worries - testing error'))
    end

    it "log_end should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_end(:test)
    end

    it "log_entry should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_entry(:test)
    end

    it "log_info should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_info(:test)
    end

    it "log_exit should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_exit(:test)
    end

    it "log_multi_exit should not log an event" do
      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.log_multi_exit(:test, [])
    end
  end

  describe "when we are sampling" do
    before do
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01')
    end

    it "log should log an event" do
      AppOpticsAPM::API.expects(:log_event)
      AppOpticsAPM::API.log(:test, 'test_label')
    end

    it "log_exception should log an event" do
      AppOpticsAPM::API.expects(:log).with do |layer, label, opts|
            layer == :test &&
            label == :error &&
            opts[:Spec] == 'error' &&
            opts[:ErrorMsg] == 'no worries - testing error' &&
            opts[:ErrorClass] == 'StandardError'
      end.once
      AppOpticsAPM::API.log_exception(:test, StandardError.new('no worries - testing error'))
    end

    it "log_exception should only log an exception once" do
      exception = StandardError.new('no worries - testing error')
      AppOpticsAPM::API.expects(:log).once

      AppOpticsAPM::API.log_exception(:test_0, exception)
      AppOpticsAPM::API.log_exception(:test_1, exception)

    end

    it "log_end should log an event" do
      AppOpticsAPM::API.expects(:log_event)
      AppOpticsAPM::API.log_end(:test)
    end

    it "log_entry should log an event" do
      AppOpticsAPM::API.expects(:log_event)
      AppOpticsAPM::API.log_entry(:test)
    end

    it "log_info should log an event" do
      AppOpticsAPM::API.expects(:log_event)
      AppOpticsAPM::API.log_info(:test)
    end

    it "log_exit should log an event" do
      AppOpticsAPM::API.expects(:log_event)
      AppOpticsAPM::API.log_exit(:test)
    end

    it "log_multi_exit should log an event" do
      AppOpticsAPM::API.expects(:log_event)
      AppOpticsAPM::API.log_multi_exit(:test, [])
    end
  end

  describe "when we use the op parameter" do
    before do
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01')
      AppOpticsAPM.layer_op = nil
    end

    it "should add and remove the layer_op (same op)" do
      AppOpticsAPM::API.log_entry(:test, {}, :test)
      AppOpticsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test)
      AppOpticsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test)
      AppOpticsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test)
      assert_equal [:test], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test)

      assert_empty AppOpticsAPM.layer_op
    end

    it "should add and remove the layer_op (different ops)" do
      AppOpticsAPM::API.log_entry(:test, {}, :test)
      AppOpticsAPM::API.log_entry(:test, {}, :test_2)
      assert_equal [:test, :test_2], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test_2)
      AppOpticsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test)
      AppOpticsAPM::API.log_entry(:test, {}, :test_3)
      assert_equal [:test, :test_3], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test_3)
      assert_equal [:test], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test)

      assert_empty AppOpticsAPM.layer_op
    end

    it "should stack ops even if they repeat" do
      AppOpticsAPM::API.log_entry(:test, {}, :test)
      AppOpticsAPM::API.log_entry(:test, {}, :test_2)
      assert_equal [:test, :test_2], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_entry(:test, {}, :test)
      assert_equal [:test, :test_2, :test], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test)
      assert_equal [:test, :test_2], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test_2)
      assert_equal [:test], AppOpticsAPM.layer_op
      AppOpticsAPM::API.log_exit(:test, {}, :test)

      assert_empty AppOpticsAPM.layer_op
    end

  end
end
