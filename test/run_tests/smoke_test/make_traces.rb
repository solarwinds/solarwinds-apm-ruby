# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

###############################################################
# TEST CASES WITH SDK METHODS
###############################################################
# these are used by the GitHub action ... with traces showing up in staging

require 'solarwinds_apm'

name = ENV['HOSTNAME'] || 'no_name'

unless SolarWindsAPM::SDK.solarwinds_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end

###############################################################
### ADD A SPAN
###############################################################
#
# SolarWindsAPM::SDK.trace()
# This method adds a span to a trace that has been started either
# by the auto-instrumentation of the gem handling incoming requests
# or the SDK method `start_trace`.
# If this method is called outside of the context of a started
# trace no spans will be created.
#
# The argument is the name for the span

SolarWindsAPM::SDK.trace("#{name}_no_show") do
  [9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort
end

###############################################################
# START A TRACE, ADD A SPAN, AND LOG AN INFO EVENT
###############################################################
#
# SolarWindsAPM::SDK.start_trace()
# This method starts a trace.  It is handy for background jobs,
# workers, or scripts, that are not part of a rack application

SolarWindsAPM::SDK.start_trace("#{name}_top") do
  SolarWindsAPM::SDK.trace("#{name}_span") do
    [9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort
    SolarWindsAPM::SDK.log_info({ some: :fancy, hash: :to, send: 1 })
  end
end

###############################################################
# START A TRACE AND PROFILE
###############################################################
#
# SolarWindsAPM::Profiling.run
# This method adds profiling for the code executed in the block

SolarWindsAPM::SDK.start_trace("#{name}_profiling") do
  SolarWindsAPM::Profiling.run do
    10.times do
      [9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort
      sleep 0.2
    end
  end
end


###############################################################
# LOG AN ERROR EVENT
###############################################################
#
# SolarWindsAPM::SDK.log_exception()
# This method adds an error event to the trace, which will be
# displayed and counted as exception on the appoptics dashboard.

def do_raise
  raise StandardError.new("oops")
end

SolarWindsAPM::SDK.start_trace("#{name}_exception") do
  begin
    do_raise
  rescue => e
    SolarWindsAPM::SDK.log_exception(e)
  end
end

###############################################################
# TRACE A METHOD
###############################################################
#
# SolarWindsAPM::SDK.trace_method()
# This creates a span every time the defined method is run.
# The method can be of any (accessible) type (instance,
# singleton, private, protected etc.).

module ExampleModule
  def self.do_sum(a, b)
    a + b
  end
end

SolarWindsAPM::SDK.trace_method(ExampleModule,
                               :do_sum,
                               config: { name: 'computation', backtrace: true },
                               kvs: { CustomKey: "some_info"})

SolarWindsAPM::SDK.start_trace("#{name}_method") do
  ExampleModule.do_sum(1, 2)
  ExampleModule.do_sum(3, 4)
end

###############################################################
# SET A CUSTOM TRANSACTION NAME
###############################################################
#
# SolarWindsAPM::SDK.set_transaction_name()
#
# this method can be called anytime after a trace has been started to add a
# custom name for the whole transaction.
# In case of a controller the trace is usually started in rack.

class FakeController
  def create(params)
    SolarWindsAPM::SDK.set_transaction_name("#{params[:name]}_transaction_name")
  end
end

SolarWindsAPM::SDK.start_trace('set_transaction_name') do
  FakeController.new.create(name: name)
end

###############################################################
# LOG INJECTION OF TRACE_ID
###############################################################
#
# SolarWindsAPM::SDK.current_trace_info
# This method creates an object with the current trace ID and
# helper methods to add the ID to logs for cross-referencing.

SolarWindsAPM::Config[:log_traceId] = :always

SolarWindsAPM::SDK.start_trace("#{name}_log_trace_id") do
  trace = SolarWindsAPM::SDK.current_trace_info
  SolarWindsAPM.logger.warn "Find this TraceInfo in the logs: #{trace.for_log}"
end
