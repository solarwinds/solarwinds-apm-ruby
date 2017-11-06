require 'appoptics/thread_local'

module Oboe
  extend AppOpticsBase
  if AppOptics.loaded
    include Oboe_metal
  end

  #
  # Support for Oboe::API calls
  #
  module API
    include AppOptics::API
    extend ::AppOptics::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args, &blk)
      # Notify of deprecation only once
      unless @deprecated_notified
        AppOptics.logger.warn "[appoptics/warn] Note that Oboe::API has been renamed to AppOptics::API. (#{sym}:#{args})"
        AppOptics.logger.warn '[appoptics/warn] Oboe::API will be deprecated in a future version.'
        AppOptics.logger.warn "[appoptics/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      AppOptics::API.send(sym, *args, &blk)
    end
  end


  #
  # Support for Oboe::Config calls
  #
  module Config
    extend ::AppOptics::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args)
      # Notify of deprecation only once
      unless @deprecated_notified
        AppOptics.logger.warn "[appoptics/warn] Note that Oboe::Config has been renamed to AppOptics::Config. (#{sym}:#{args})"
        AppOptics.logger.warn '[appoptics/warn] Oboe::Config will be deprecated in a future version.'
        AppOptics.logger.warn "[appoptics/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      AppOptics::Config.send(sym, *args)
    end
  end

  #
  # Support for legacy Oboe::Ruby.load calls
  #
  module Ruby
    extend ::AppOptics::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args)
      # Notify of deprecation only once
      unless @deprecated_notified
        AppOptics.logger.warn "[appoptics/warn] Note that Oboe::Ruby has been renamed to AppOptics::Ruby. (#{sym}:#{args})"
        AppOptics.logger.warn '[appoptics/warn] Oboe::Ruby will be deprecated in a future version.'
        AppOptics.logger.warn "[appoptics/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      AppOptics::Ruby.send(sym, *args)
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
    include AppOpticsMethodProfiling::ClassMethods
  end
end
