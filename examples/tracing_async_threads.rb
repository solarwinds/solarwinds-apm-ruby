#
# This sample demonstrates how to instrument a main loop that
# retrieves work and spawn threads that do the actual work
#

require 'math'
require 'oboe'

AppOpticsAPM::Config[:tracing_mode] = :always
AppOpticsAPM::Config[:verbose] = true

# The parent process/loop which collects data
Kernel.loop do

  # For each loop, we instrument the work retrieval.  These traces
  # will show up as layer 'get_the_work'.
  AppOpticsAPM::API.start_trace('get_the_work') do
    work = get_the_work

    # Loop through work and pass to `do_the_work` method
    # that spawns a thread each time
    work.each do |j|

      # In the new Thread block, the AppOpticsAPM tracing context isn't there
      # so we carry it over manually and pass it to the `start_trace`
      # method.

      # In the AppOpticsAPM dashboard, this will show up as parent traces
      # (layer 'get_the_work') with child traces (layer 'do_the_work').

      tracing_context = AppOpticsAPM::Context.toString

      Thread.new do
        result = nil

        AppOpticsAPM::API.start_trace('do_the_work', tracing_context, :Async => 1) do
          result = do_the_work(j)
        end

        result
      end
    end
  end
  sleep 5
end


##
# get_the_work
#
# Method to retrieve work to do
#
def get_the_work
  # We'll just return random integers as a
  # fake work load
  w = []
  w << rand(25)
  w << rand(25)
  w << rand(25)
end

##
# do_the_work
#
# The work-horse method
#
def do_the_work(job_to_do)
  i = job_to_do
  i * Math::PI
end

####################################################
# Notes
####################################################

# The above code generates a trace for each loop of the parent data collection process.
# Those traces have the layer name of `get_the_work` and will show up in the AppOpticsAPM
# dashboard as such.
#
# Then as threads are spawned to process individual bits of work, we carry over the
# `tracing_context` and start a new asynchronous trace using `start_trace`.  (An
# asynchronous trace is noted by passing the `Async` Hash key with a value of `1`).
#
# In the AppOpticsAPM dashboard, the two traces (parent and child; or one to many) will
# be linked and displayed together as a single trace.

####################################################
# Caveats
####################################################

# If the main loop is retrieving many jobs (work) to process on each loop then
# linking the traces may not be the best strategy as such large relationships
# are difficult to display correctly in the AppOpticsAPM dashboard and provide little
# added value.
#
# If there are more than 8 - 12 threads spawned from each loop, then you may want to consider
# NOT carrying over tracing context into the spawned threads.
#
# In this case, you can simply omit `tracing_context` and passing it to `start_trace` in
# the `Thread.new` block. (lines 32 + 37).  Also remove the `{ Async => 1 }` Hash!
#
# This will produce two sets of traces with two the layer names 'get_the_work' +
# 'do_the_work'.
#
# In the AppOpticsAPM dashboard, you can then separate or unify these traces into
# independent applications.  e.g. job processor, data retrieval, thread worker etc...
#
# An implementation of the work loop without carrying over tracing context would look
# like the following:
#
#    work.each do |j|
#      Thread.new do
#        result = nil
#
#        AppOpticsAPM::API.start_trace('do_the_work') do
#          result = do_the_work(j)
#        end
#
#        result
#      end
#    end
#
# If anything isn't clear, please don't hesitate to reach us at support (support@appoptics.com).
#
