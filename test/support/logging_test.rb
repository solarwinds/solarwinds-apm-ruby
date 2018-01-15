# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/mini_test'

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
      AppOpticsAPM::API.expects(:log_event)
      AppOpticsAPM::API.log_exception(:test, StandardError.new('no worries - testing error'))
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
end
