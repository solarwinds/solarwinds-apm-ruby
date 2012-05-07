# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module OboeFu
  module Loading
    def self.require_instrumentation
      require 'oboe'
      require 'oboefu/config'

      pattern = File.join(File.dirname(__FILE__), 'api', '*.rb')
      Dir.glob(pattern) do |f|
        require f
      end
      require 'oboefu/api'

      pattern = File.join(File.dirname(__FILE__), 'inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          puts "[oboe_fu/loading] Instrumentation '#{f}'"
          require f
        rescue => e
          $stderr.puts "[oboe_fu/loading] Error loading insrumentation file '#{f}' : #{e}"
        end
      end
    end
  end
end
