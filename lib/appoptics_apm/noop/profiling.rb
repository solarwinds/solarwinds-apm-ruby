module AppOpticsAPM
  class Profiling

    def self.run
      yield
    end
  end

  module CProfiler
    def self.set_interval(_)
      # do nothing
    end

    def self.get_tid
      return 0
    end
  end
end
