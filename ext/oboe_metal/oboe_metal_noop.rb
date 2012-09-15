# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module OboeMetal
  class Context
    def self.log(layer, label, options = {})
    end

    def self.isValid
      false
    end

    def self.startTrace
      false
    end

    def self.addInfo(*args)
    end
  end
end


module OboeMethodProfiling
    def self.included klass
    end

    module ClassMethods
        def profile_method(method_name, profile_name, store_args=false, store_return=false, profile=false)
        end
    end
end
  
module Oboe
  include OboeMetal

  # TODO: Ensure that the :tracing_mode is set to "always", "through", or "never"
  Config = {
    :tracing_mode => "through",
    :reporter_host => "127.0.0.1",
    :sample_rate => 1000000
  }

  def self.passthrough?
    false
  end

  def self.always?
    false
  end

  def self.through?
    false
  end

  def self.never?
    true
  end

  def self.now?
    false
  end

  def self.start?
    false
  end

  def self.continue?
    false
  end

  def self.log(layer, label, options = {})
  end

  def self.reporter
    if !@reporter
      @reporter = Oboe::UdpReporter.new(Oboe::Config[:reporter_host])
    end

    return @reporter
  end
end

#Oboe::Context.init()
