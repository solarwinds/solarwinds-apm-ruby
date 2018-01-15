###############################################################
# A brief overview of AppOpticsAPM tracing context
###############################################################
#
# Tracing context is the state held when AppOpticsAPM is instrumenting a
# transaction, block, request etc..  This context is advanced as
# new blocks are instrumented and this chain of context is used
# by AppOpticsAPM to later reassemble performance data to be displayed
# in the AppOptics dashboard.
#
# Tracing context is non-existent until established by calling
# `AppOpticsAPM::API.start_trace` or `AppOpticsAPM::API.log_start`.  Those methods
# are part of the high-level and low-level API respectively.
#
# After a tracing context is established, that context can be
# continued by calling `AppOpticsAPM::API.trace` or `AppOpticsAPM::API.log_entry`.
# These methods will advance an existing context but not start
# new one.
#
# For example, when a web request comes into a stack, a tracing
# context is established using `AppOpticsAPM::API.log_start` as the request
# enters through the rack middleware via `::AppOpticsAPM::Rack`.
#
# That tracing context is then continued using `AppOpticsAPM::API.trace` or
# `AppOpticsAPM::API.log_entry` for each subsequent layer such as Rails,
# ActiveRecord, Redis, Memcache, ActionView, Mongo (etc...) until
# finally request processing is complete and the tracing context
# is cleared (AppOpticsAPM::Context.clear)
#

###############################################################
# Carrying Context
###############################################################
#
# The tracing context exists in the form of an X-Trace string and
# can be retrieved using 'AppOpticsAPM::Context.toString'
#
# xtrace = AppOpticsAPM::Context.toString
#
# => "1B4EDAB9E028CA3C81BCD57CC4644B4C4AE239C7B713F0BCB9FAD6D562"
#
# Tracing context can also be picked up from a pre-existing
# X-Trace string:
#
# xtrace = "1B4EDAB9E028CA3C81BCD57CC4644B4C4AE239C7B713F0BCB9FAD6D562"
#
# AppOpticsAPM::Context.fromString(xtrace)
#
# With these two methods, context can be passed across threads,
# processes (via fork) and in requests (such as external HTTP
# requests where the X-Trace is inserted in request headers).
#
#

###############################################################
# Two Options for Spawned Tracing
###############################################################
#
# When your application needs to instrument code that forks,
# spawns a thread or does something in-parallel, you have the
# option to either link those child traces to the parent or
# trace them as individuals (but with identifying information).
#
# Linking parent and child has it's benefits as in the
# AppOptics dashboard, you will see how a process may spawn
# a task in parallel and in a single view see the performance
# of both.
#
# The limitation of this is that this is only useful if your
# parent process spawns only a limited number of child traces.
#
# If your parent process is spawning many child tasks (e.g.
# twenty, hundreds, thousands or more) it's best to trace those
# child tasks as individuals and pass in identifier Key-Values
# (such as task ID, job ID etc..)
#
# In the examples below, I show implementations of both linked
# asynchronous traces and separated independent traces.

###############################################################
# Thread - with separated traces
###############################################################

AppOpticsAPM::API.log_start('parent')

# Get the work to be done
job = get_work

Thread.new do
  # This is a new thread so there is no pre-existing context so
  # we'll call `AppOpticsAPM::API.log_start` to start a new trace context.
  AppOpticsAPM::API.log_start('worker_thread', :job_id => job.id)

  # Do the work
  do_the_work(job)

  AppOpticsAPM::API.log_end('worker_thread')
end

AppOpticsAPM::API.log_end('parent')

###############################################################
#
# This will generate two independent traces with the following
# topology.
#
# 'parent'
# ------------------------------------------------------------
#
# 'worker_thread'
# ------------------------------------------------------------
#

###############################################################
# Thread - with linked asynchronous traces
###############################################################

# Since the following example spawns a thread without waiting
# for it to return, we carry over the context and we mark the
# trace generated in that thread to be asynchronous using
# the `Async` flag.

AppOpticsAPM::API.log_start('parent')

# Save the context to be imported in spawned thread
tracing_context = AppOpticsAPM::Context.toString

# Get the work to be done
job = get_work

Thread.new do
  # Restore context
  AppOpticsAPM::Context.fromString(tracing_context)

  AppOpticsAPM::API.log_entry('worker_thread')

  # Do the work
  do_the_work(job)

  AppOpticsAPM::API.log_exit('worker_thread', :Async => 1)
end

AppOpticsAPM::API.log_end('parent')

###############################################################
#
# This will generate a single trace with an asynchronous
# branch like the following
#
# 'parent'
# ------------------------------------------------------------
#     \
#      \
#       ------------------------------------------------------
#        'worker_thread'
#

###############################################################
# Process via fork - with separated traces
###############################################################

AppOpticsAPM::API.start_trace('parent_process') do
  # Get some work to process
  job = get_job

  # fork process to handle work
  fork do
    # Since fork does a complete process copy, the tracing_context still exists
    # so we have to clear it and start again.
    AppOpticsAPM::Context.clear

    AppOpticsAPM::API.start_trace('worker_process', nil, :job_id => job.id) do
      do_work(job)
    end
  end

end

###############################################################
#
# This will generate two independent traces:
#
# 'parent_process'
# ------------------------------------------------------------
#
# 'worker_process'
# ------------------------------------------------------------
#
###############################################################
# Process via fork - with linked asynchronous traces
###############################################################

AppOpticsAPM::API.start_trace('parent_process') do
  # Get some work to process
  job = get_job

  # fork process to handle work
  fork do
    # Since fork does a complete process copy, the tracing_context still exists
    # although we'll have to mark these traces as asynchronous to denote
    # that it has split off from the main program flow

    AppOpticsAPM::API.trace('worker_process', :Async => 1) do
      do_work(job)
    end
  end
end

###############################################################
#
# This will generate a single trace with an asynchronous
# branch like the following
#
# 'parent_process'
# ------------------------------------------------------------
#     \
#      \
#       ------------------------------------------------------
#        'worker_process'
#
