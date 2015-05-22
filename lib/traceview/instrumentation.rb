# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  ##
  # The Inst module holds all of the instrumentation extensions for various
  # libraries suchs as Redis, Dalli and Resque.
  module Inst
    def self.load_instrumentation
      # Load the general instrumentation
      pattern = File.join(File.dirname(__FILE__), 'inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          TraceView.logger.error "[traceview/loading] Error loading instrumentation file '#{f}' : #{e}"
        end
      end
    end
  end
end
