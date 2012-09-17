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
        # Force load the tracelytics user initializer if there is one
        tr_initializer = "#{Rails.root}/config/initializers/tracelytics.rb"
        require tr_initializer if File.exists?(tr_initializer)
      
        puts "[oboe] loading ..." if Oboe::Config[:verbose]

        Oboe::API.extend_with_tracing
      rescue LoadError => e
        Oboe::API.extend_with_noop
      end

      require 'oboe/config'
    end

    def self.load_rails_instrumentation
      pattern = File.join(File.dirname(__FILE__), 'frameworks/rails/inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          $stderr.puts "[oboe/loading] Error loading insrumentation file '#{f}' : #{e}"
        end
      end
    end
    
    def self.instrument_rails
      if defined?(Rails) 
        Oboe::Loading.load_rails_instrumentation
      end
    end

  end
end
