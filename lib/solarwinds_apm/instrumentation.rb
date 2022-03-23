# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  ##
  # The Inst module holds all of the instrumentation extensions for various
  # libraries such as Redis, Dalli and Resque.
  module Inst
    def self.load_instrumentation
      # Load the general instrumentation
      pattern = File.join(File.dirname(__FILE__), 'inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          SolarWindsAPM.logger.error "[solarwinds_apm/loading] Error loading instrumentation file '#{f}' : #{e}"
          SolarWindsAPM.logger.debug "[solarwinds_apm/loading] #{e.backtrace.first}"
        end
      end
    end
  end
end
