
###############################################################
# BASIC TRACING EXAMPLES
###############################################################

# set APPOPTICS_SERVICE_KEY and run with
# `bundle exec ruby 01_basic_tracing.rb`

require 'appoptics_apm'
unless AppopticsAPM::SDK.appoptics_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end


###############################################################
# Starting a trace and adding a span
###############################################################

# USE CASE:
# You may want to either trace a piece of your own code or a
# call to a method from a gem that isn't auto-instrumented by
# appoptics_apm

# The first example will not create a span, because no trace has
# been started, but the second and third ones will.

# The string argument is the name for the span

##
# AppOpticsAPM::SDK.trace()
# most of the time this is the method you need.  It adds a span
# to a trace that has probably been started by rack.

# Example 1
def do_work
  42
end

AppOpticsAPM::SDK.trace('simple_span') do
  do_work
end

##
# AppOpticsAPM::SDK.start_trace()
# This method starts a trace.  It is handy for background jobs,
# workers, or scripts, that are not part of a rack application

# Example 2
AppOpticsAPM::SDK.start_trace('outer_span') do

  AppOpticsAPM::SDK.trace('simple_span') do
    do_work
    AppOpticsAPM::API.log_info(AppOpticsAPM.layer, { some: :fancy, hash: :to, send: 1 })
  end

end

# Example 3
def do_traced_work
  AppOpticsAPM::SDK.trace('simple_span_2') do
    do_work
  end
end

AppOpticsAPM::SDK.start_trace('outer_span_2') do
  do_traced_work
end
