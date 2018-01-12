require 'appoptics_apm/thread_local'

module Oboe
  extend AppOpticsAPMBase
  if AppOpticsAPM.loaded
    include Oboe_metal
  end

  #
  # Support for Oboe::API calls
  #
  module API
    include AppOpticsAPM::API
    extend ::AppOpticsAPM::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args, &blk)
      # Notify of deprecation only once
      unless @deprecated_notified
        AppOpticsAPM.logger.warn "[appoptics_apm/warn] Note that Oboe::API has been renamed to AppOpticsAPM::API. (#{sym}:#{args})"
        AppOpticsAPM.logger.warn '[appoptics_apm/warn] Oboe::API will be deprecated in a future version.'
        AppOpticsAPM.logger.warn "[appoptics_apm/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      AppOpticsAPM::API.send(sym, *args, &blk)
    end
  end


  #
  # Support for Oboe::Config calls
  #
  module Config
    extend ::AppOpticsAPM::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args)
      # Notify of deprecation only once
      unless @deprecated_notified
        AppOpticsAPM.logger.warn "[appoptics_apm/warn] Note that Oboe::Config has been renamed to AppOpticsAPM::Config. (#{sym}:#{args})"
        AppOpticsAPM.logger.warn '[appoptics_apm/warn] Oboe::Config will be deprecated in a future version.'
        AppOpticsAPM.logger.warn "[appoptics_apm/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      AppOpticsAPM::Config.send(sym, *args)
    end
  end

  #
  # Support for legacy Oboe::Ruby.load calls
  #
  module Ruby
    extend ::AppOpticsAPM::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args)
      # Notify of deprecation only once
      unless @deprecated_notified
        AppOpticsAPM.logger.warn "[appoptics_apm/warn] Note that Oboe::Ruby has been renamed to AppOpticsAPM::Ruby. (#{sym}:#{args})"
        AppOpticsAPM.logger.warn '[appoptics_apm/warn] Oboe::Ruby will be deprecated in a future version.'
        AppOpticsAPM.logger.warn "[appoptics_apm/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      AppOpticsAPM::Ruby.send(sym, *args)
    end
  end
end

#
# Support for OboeMethodProfiling
#
module OboeMethodProfiling
  def self.included(klass)
    klass.extend ClassMethods
  end

  module ClassMethods
    include AppOpticsAPMMethodProfiling::ClassMethods
  end
end
