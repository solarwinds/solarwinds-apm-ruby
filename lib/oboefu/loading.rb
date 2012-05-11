# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module OboeFu
  module Loading
    def self.require_api
      require 'oboefu/config'

      pattern = File.join(File.dirname(__FILE__), 'api', '*.rb')
      Dir.glob(pattern) do |f|
        require f
      end
      require 'oboefu/api'

      begin
        require 'oboe'
        Oboe::API.extend_with_tracing
      rescue LoadError => e
        Oboe::API.extend_with_noop
      end
    end

    def self.require_instrumentation
      self.require_api

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
