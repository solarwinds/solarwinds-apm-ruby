# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  
  def self.always?
    Oboe::Config[:tracing_mode].to_s == "always"
  end
  
  def self.continue?
    Oboe::Context.isValid and not Oboe.never?
  end
  
  def self.log(layer, label, options = {})
    Context.log(layer, label, options = options)
  end

  def self.never?
    Oboe::Config[:tracing_mode].to_s == "never"
  end

  def self.now?
    Oboe::Context.isValid and not Oboe.never?
  end
  
  def self.passthrough?
    ["always", "through"].include?(Oboe::Config[:tracing_mode])
  end
    
  def self.sample?
    # Note that this the only point in the code that currently does and
    # should ever read the sample rate. When autopilot is released, modify
    # the line below and that line only.
    Oboe::Config[:sample_rate].to_i < rand(1e6)
  end

  def self.start?
    not Oboe::Context.isValid and Oboe.always?
  end
  
  def self.through?
    Oboe::Config[:tracing_mode] == "through"
  end
    
  def self.tracing?
    Oboe::Context.isValid and not Oboe.never?
  end

  ############################
  # Oboe Configuration Module
  ############################
  module Config
    mattr_reader :config

    @@config = {}

    @@instrumentation = [ :cassandra, :dalli, :nethttp, :memcached, :memcache, :mongo,
                          :moped, :rack, :resque, :action_controller, :action_view, 
                          :active_record ]

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

      update!(data)
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

config = {
      :tracing_mode => "through",
      :reporter_host => "127.0.0.1",
      :sample_rate => 1000000,
      :verbose => false }

Oboe::Config.initialize(config)

