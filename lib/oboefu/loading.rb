# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module OboeFu
  module Loading

    def self.require_api
      puts "[oboe_fu] loading ..."

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

      require 'oboefu/config'
      require 'oboefu/version'
    end

    def self.require_instrumentation
      self.require_api

      pattern = File.join(File.dirname(__FILE__), 'inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          $stderr.puts "[oboe_fu/loading] Error loading insrumentation file '#{f}' : #{e}"
        end
      end
    end
  end
end
