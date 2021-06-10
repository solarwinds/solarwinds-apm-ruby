# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  class Profiling

    def self.run
      # allow enabling and disabling and setting interval interactively
      return yield unless AppOpticsAPM::Config.profiling == :enabled && AppOpticsAPM.tracing?

      CProfiler.run(Thread.current, AppOpticsAPM::Config.profiling_interval) do
        # for some reason `return` is needed here
        # this is yielded by c-code, but why it needs `return` ... ????
        return yield
      end
    end
  end
end
