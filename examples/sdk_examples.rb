# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

###############################################################
# SDK EXAMPLES
###############################################################
# Use cases:
# You may want to either trace a piece of your own code or a
# method call from a gem that isn't auto-instrumented by
# appoptics_apm

###############################################################
# Prerequisits
# export APPOPTICS_SERVICE_KEY=<API token>:<service_name>
# `bundle exec ruby sdk_examples.rb`
# 5 traced requests will show up at https://my.appoptics.com/
###############################################################

require 'appoptics_apm'

unless AppOpticsAPM::SDK.appoptics_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end

###############################################################
### ADD A SPAN
###############################################################
#
# AppOpticsAPM::SDK.trace()
# This method adds a span to a trace that has been started either
# by the SDK method `start_trace` or by rack.
# It will not create a trace if it is called outside of the
# context of a started trace.
#
# The argument is the name for the span

AppOpticsAPM::SDK.trace('span_name') do
  [9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort
end

###############################################################
# START A TRACE, ADD A SPAN, AND LOG AN INFO EVENT
###############################################################
#
# AppOpticsAPM::SDK.start_trace()
# This method starts a trace.  It is handy for background jobs,
# workers, or scripts, that are not part of a rack application

AppOpticsAPM::SDK.start_trace('outer_span') do
  AppOpticsAPM::SDK.trace('first_child_span') do
    [9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort
    AppOpticsAPM::SDK.log_info({ some: :fancy, hash: :to, send: 1 })
  end
end

###############################################################
# LOG AN ERROR EVENT
###############################################################
#
# AppOpticsAPM::SDK.log_exception()
# This method adds an error event to the trace, which will show
# up and be counted as exception on the appoptics dashboard.

def do_raise
  raise StandardError.new("oops")
end

AppOpticsAPM::SDK.start_trace('with_error') do
  begin
    do_raise
  rescue => e
    AppOpticsAPM::SDK.log_exception(e)
  end
end

###############################################################
# TRACE A METHOD
###############################################################
#
# AppOpticsAPM::SDK.trace_method()
# This creates a span every time the defined method is run.
# The method can be of any (accessible) type (instance,
# singleton, private, protected etc.).

module ExampleModule
  def self.do_sum(a, b)
    a + b
  end
end

AppOpticsAPM::SDK.trace_method(ExampleModule,
                               :do_sum,
                               { name: 'computation', backtrace: true },
                               { CustomKey: "some_info"})

AppOpticsAPM::SDK.start_trace('trace_a_method') do
  ExampleModule.do_sum(1, 2)
  ExampleModule.do_sum(3, 4)
end

###############################################################
# ADD A TRANSACTION NAME
###############################################################
#
# AppOpticsAPM::SDK.set_transaction_name()
#
# this method can be called anytime after a trace has been started to add a
# custom name for the whole transaction.
# In case of a controller the trace is usually started in rack.

class FakeController
  def create(params)
    # @fake = fake.new(params.permit(:type, :title))
    # @fake.save
    AppOpticsAPM::SDK.set_transaction_name("fake.#{params[:type]}")
    # redirect_to @fake
  end
end

AppOpticsAPM::SDK.start_trace('set_transaction_name') do
  FakeController.new.create(type: 'news')
end

###############################################################
# LOG INJECTION OF TRACE_ID
###############################################################
#
# AppOpticsAPM::SDK.current_trace
# This method creates an object with the current trace ID and
# helper methods to add the ID to logs for cross-referencing.

AppOpticsAPM::Config[:log_traceId] = :always

AppOpticsAPM::SDK.start_trace('log_trace_id') do
  trace = AppOpticsAPM::SDK.current_trace
  AppOpticsAPM.logger.warn "Some log message #{trace.for_log}"
end
