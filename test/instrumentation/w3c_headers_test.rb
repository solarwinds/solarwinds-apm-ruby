# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "W3CHeadersTest" do

  describe "no traceparent" do
    it "adds a traceparent and a tracesstate header" do
      skip
    end

    it "removes incoming tracestate" do
      skip
    end
  end

  describe "Valid traceparent" do
    it "reads the traceheader" do
      skip
    end

    it "reads the traceheader independent of capitalization" do
      skip
    end

    it "adds headers for an incoming sampling request with headers from us" do
      skip
    end

    it "adds headers for an incoming sampling request with headers from other vendor" do
      skip
    #  this can result in a sampling or non sampling decision
    end

    it "adds headers for an incoming NON-sampling request with headers from us" do
      skip
    end

    it "adds headers for an incoming NON-sampling request with headers from other vendor" do
      skip
      #  this can result in a sampling or non sampling decision
    end

  end

  describe "Invalid traceparent" do
    it "uses a new taskid and discards incoming tracestate" do
      skip
    # TODO: check each component of the traceparent:
    #       version, taskId, parentId, flags
    end

  end

  describe "tracestate header" do
    # TODO the traceparent is still valid even when the tracestate is not

    it "reads the tracestate independent of capitalization" do
      skip
    end

    it "adds our entry" do
      skip
    end

    it "replaces our entry" do
      skip
    end

    it "replaces our entry when there are multiple entries" do
      skip
    end

    it "removes invalid entries" do
      skip
    end

    it "discards the header if it cannot be parsed" do
      skip
    end

    it "combines multiple tracestate headers" do
      # TODO according to standard https://httpwg.org/specs/rfc7230.html#field.order
      #  they can be joined by comma
      skip
    end

  end



end