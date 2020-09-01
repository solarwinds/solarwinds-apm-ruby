# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  class Profiling
    CProfiler.set_interval(AppOpticsAPM::Config.profiling_interval)

    def self.run
     return yield unless AppOpticsAPM::Config.profiling == :enabled && AppOpticsAPM.tracing?

     CProfiler.run(Thread.current) do
        # for some reason `return` is needed here
        # this is yielded by c-code, but why it needs `return` ... ????
        return yield
      end
    end
  end
end
