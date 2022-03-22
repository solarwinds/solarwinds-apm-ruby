# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  class Profiling

    def self.run
      # TODO
      #  add back at some point but for now NH is not ready for profiling
      SolarWindsAPM::Config.profiling = :disabled

      # allow enabling and disabling and setting interval interactively
      return yield unless SolarWindsAPM::Config.profiling == :enabled && SolarWindsAPM.tracing?

      CProfiler.run(Thread.current, SolarWindsAPM::Config.profiling_interval) do
        # for some reason `return` is needed here
        # this is yielded by c-code, but why it needs `return` ... ????
        return yield
      end
    end
  end
end
