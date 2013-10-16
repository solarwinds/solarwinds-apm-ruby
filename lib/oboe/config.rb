# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  ##
  # This module exposes a nested configuration hash that can be used to
  # configure and/or modify the functionality of the oboe gem.
  #
  # Use Oboe::Config.show to view the entire nested hash.
  #
  module Config
    @@config = {}

    @@instrumentation = [ :cassandra, :dalli, :nethttp, :memcached, :memcache, :mongo,
                          :moped, :rack, :resque, :action_controller, :action_view, 
                          :active_record ]

    ##
    # Return the raw nested hash.
    #
    def self.show
      @@config
    end

    def self.initialize(data={})
      # Setup default instrumentation values
      @@instrumentation.each do |k|
        @@config[k] = {}
        @@config[k][:enabled] = true
        @@config[k][:log_args] = true
      end

      # Special instrument specific flags
      #
      # :link_workers - associates enqueue operations with the jobs they queue by piggybacking
      #                 an additional argument that is stripped prior to job proecessing 
      #                 !!Note: Make sure both the queue side and the Resque workers are instrumented
      #                 or jobs will fail
      #                 (Default: false)
      @@config[:resque][:link_workers] = false

      # Setup an empty host blacklist (see: Oboe::API::Util.blacklisted?)
      @@config[:blacklist] = []

      # The oboe Ruby client has the ability to sanitize query literals
      # from SQL statements.  By default this is disabled.  Enable to
      # avoid collecting and reporting query literals to TraceView.
      @@config[:sanitize_sql] = false

      # The default configuration
      default_config = {
        :tracing_mode => "through",
        :reporter_host => "127.0.0.1",
        :sample_rate => 300000,
        :verbose => false 
      }
      update!(default_config)
      
      # For Initialization, mark this as the default SampleRate
      @@config[:sample_source] = 2 # OBOE_SAMPLE_RATE_SOURCE_DEFAULT
    end

    def self.update!(data)
      data.each do |key, value|
        self[key] = value
      end
    end

    def self.[](key)
      @@config[key.to_sym]
    end

    def self.[]=(key, value)
      @@config[key.to_sym] = value

      if key == :sampling_rate
        Oboe.logger.warn "WARNING: :sampling_rate is not a supported setting for Oboe::Config.  Please use :sample_rate."
      end

      if key == :sample_rate
        # When setting SampleRate, note that it's been manually set
        # OBOE_SAMPLE_RATE_SOURCE_FILE == 1
        @@config[:sample_source] = 1 

        unless value.is_a?(Integer) or value.is_a?(Float)
          raise "oboe :sample_rate must be a number between 1 and 1000000 (1m)" 
        end
       
        # Validate :sample_rate value
        unless value.between?(1, 1e6)
          raise "oboe :sample_rate must be between 1 and 1000000 (1m)" 
        end

        # Assure value is an integer
        @@config[key.to_sym] = value.to_i

        # Update liboboe with the new SampleRate value
        Oboe::Context.setDefaultSampleRate(value.to_i)
      end

      # Update liboboe if updating :tracing_mode
      if key == :tracing_mode
        case value.downcase
        when 'never'
          # OBOE_TRACE_NEVER
          Oboe::Context.setTracingMode(0)
        when 'always'
          # OBOE_TRACE_ALWAYS
          Oboe::Context.setTracingMode(1)
        else
          # OBOE_TRACE_THROUGH
          Oboe::Context.setTracingMode(2)
        end
      end
    end

    def self.method_missing(sym, *args)
      if sym.to_s =~ /(.+)=$/
        self[$1] = args.first
      else
        self[sym]
      end
    end
  end
end

Oboe::Config.initialize

