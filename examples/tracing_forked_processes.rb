#
# This sample demonstrates how to instrument a main loop that
# retrieves work and calls fork to do the actual work
#

require 'math'
require 'oboe'

Oboe::Config[:tracing_mode] = :always
Oboe::Config[:verbose] = true

# The parent process/loop which collects data
while true do

  # For each loop, we instrument the work retrieval.  These traces
  # will show up as layer 'get_the_work'.
  Oboe::API.start_trace('get_the_work') do

    work = get_the_work

    # Loop through work and pass to `do_the_work` method
    # that spawns a thread each time
    work.each do |job|
      fork do
        # Since the context is copied from the parent process, we clear it
        # and start a new trace via `Oboe::API.start_trace`.
        Oboe::Context.clear
        result = nil

        Oboe::API.start_trace('do_the_work', nil, :job_id => job.id) do
          result = do_the_work(job)
        end

        result
      end
    end
  end
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

#########################################################################
# Notes
#########################################################################

# If your parent process only forks a small number of processes per loop (< 5..10),
# you may want to mark the child traces as asynchronous and have them directly
# linked to the parent tracing context.
#
# The benefit of this is that instead of having two independent traces (parent
# and child), you will have a single view of the parent trace showing the
# spawned child process and it's performance in the TraceView dashboard.
#
# To do this:
#   1. Don't clear the context in the child process
#   2. Use `Oboe::API.trace` instead
#   3. Pass the `Async` flag to mark this child as asynchronous
#
while true do
  Oboe::API.start_trace('get_the_work') do

    work = get_the_work

    work.each do |job|
      fork do
        result = nil
        # 1 Don't clear context
        # 2 Use `Oboe::API.trace` instead
        # 3 Pass the Async flag
        Oboe::API.trace('do_the_work', { :job_id => job.id, 'Async' => 1 }) do
          result = do_the_work(job)
        end

        result
      end
    end
  end
end
