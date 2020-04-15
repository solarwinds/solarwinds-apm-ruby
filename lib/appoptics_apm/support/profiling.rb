# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  class Profiling
    def self.run
     return yield unless AppOpticsAPM::Config.profiling == :enabled

     AOProfiler.set_interval(AppOpticsAPM::Config.profiling_interval)
     AOProfiler.run do
        # for some reason `return` is needed here
        # this is coming out of c-code, but why it needs return ... ????
        return yield
      end
    end

    # for testing
    def self.interval=(interval)
      AOProfiler.set_interval(interval)
    end

    def self.interval
      AOProfiler.get_interval
    end

    def self.app_root(path)
      if path[0] != '/'
        path = "/#{path}"
      elsif path[1] == '/'
        path = path[1..-1]
      end

      AOProfiler.set_app_root(path)
    end

    def self.running?
      AOProfiler.running?
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
