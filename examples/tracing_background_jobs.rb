require 'rubygems'
require 'bundler'

Bundler.require

# Make sure oboe is at the bottom of your Gemfile.
# This is likely redundant but just in case.
require 'oboe'

# Tracing mode can be 'never' or 'always'
AppOpticsAPM::Config[:tracing_mode] = 'always'

#
# Update April 9, 2015 - this is done automagically now
# and doesn't have to be called manually
#
# Load library instrumentation to auto-capture stuff we know about...
# e.g. ActiveRecord, Cassandra, Dalli, Redis, Memcache, Mongo
# AppOpticsAPM::Ruby.load

# Some KVs to report to the dashboard
report_kvs = {}
report_kvs[:command_line_params] = ARGV.to_s
report_kvs[:user_id] = `whoami`

AppOpticsAPM::API.start_trace('my_background_job', nil, report_kvs) do
  #
  # Initialization code
  #

  tasks = get_all_tasks

  tasks.each do |t|
    # Optional: Here we embed another 'trace' to separate actual
    # work for each task.  In the APPOPTICS dashboard, this will show
    # up as a large 'my_background_job' parent layer with many
    # child 'task" layers.
    AppOpticsAPM::API.trace('task', :task_id => t.id) do
      t.perform
    end
  end
  #
  # cleanup code
  #
end

# Note that we use 'start_trace' in the outer block and 'trace' for
# any sub-blocks of code we wish to instrument.  The arguments for
# both methods vary slightly.
#
# TODO update location of the following doc
# Details in RubyDoc:
# https://www.omniref.com/ruby/gems/oboe/2.7.10.1/symbols/AppOpticsAPM::API::Tracing#tab=Methods
