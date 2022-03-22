module SolarWindsAPM

  # override the Ruby method, so that no code related to profiling gets executed
  class Profiling

    def self.run
      yield
    end
  end

  # these put the c-functions into "noop"
  module CProfiler
    def self.set_interval(_)
      # do nothing
    end

    def self.get_tid
      return 0
    end
  end
end
