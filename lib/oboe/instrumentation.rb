# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    def self.load_instrumentation
      # Load the general instrumentation
      pattern = File.join(File.dirname(__FILE__), 'inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          Oboe.logger.error "[oboe/loading] Error loading instrumentation file '#{f}' : #{e}"
        end
      end
    end
  end
end
