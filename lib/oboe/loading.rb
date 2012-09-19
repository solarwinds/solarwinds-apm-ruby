# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Loading

    def self.require_api
      pattern = File.join(File.dirname(__FILE__), 'api', '*.rb')
      Dir.glob(pattern) do |f|
        require f
      end
      require 'oboe/api'

      begin
        Oboe::API.extend_with_tracing
      rescue LoadError => e
        Oboe::API.extend_with_noop
      end
      
      require 'oboe/config'
    end

    def self.load_framework_instrumentation
      pattern = File.join(File.dirname(__FILE__), 'frameworks/*/', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          $stderr.puts "[oboe/loading] Error loading framework file '#{f}' : #{e}"
        end
      end

    end
  end
end

Oboe::Loading.require_api
Oboe::Loading.load_framework_instrumentation

