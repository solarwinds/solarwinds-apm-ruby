# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

# require 'rack-mini-profiler'

module AppOpticsAPM
  class Profiling
    AOProfiler = AOProfiler_V2 if ENV['AO_PROFILER_V2']
    AOProfiler.set_interval(AppOpticsAPM::Config.profiling_interval)

    def self.run
     return yield unless AppOpticsAPM::Config.profiling == :enabled && AppOpticsAPM.tracing?

     AOProfiler.run(Thread.current) do
        # for some reason `return` is needed here
        # this is yielded by c-code, but why it needs `return` ... ????
        return yield
      end
    end

    # for testing
    def self.interval=(interval)
      AOProfiler.set_interval(interval)
    end

    def self.interval
      AOProfiler.get_rb_interval
    end

    def self.running?
      AOProfiler.running?
    end

    def self.getTid
      AOProfiler.getTid
    end

    def self.stack
      my_iseq = nil
      ObjectSpace.each_iseq { |iseq| my_iseq = iseq }
      # stack = caller
      # stack.delete_if { |ele| ele =~ /block /}
      # stack = stack[1..-1] if stack[0] =~ /eval:1/
      #
      # puts "**********************************************"
      # puts stack
      # stack
    end
  end
end
