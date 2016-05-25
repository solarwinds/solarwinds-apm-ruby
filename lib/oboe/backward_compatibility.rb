require 'traceview/thread_local'

module Oboe
  extend TraceViewBase
  if TraceView.loaded
    include Oboe_metal
  end

  #
  # Support for Oboe::API calls
  #
  module API
    include TraceView::API
    extend ::TraceView::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args, &blk)
      # Notify of deprecation only once
      unless @deprecated_notified
        TraceView.logger.warn "[traceview/warn] Note that Oboe::API has been renamed to TraceView::API. (#{sym}:#{args})"
        TraceView.logger.warn '[traceview/warn] Oboe::API will be deprecated in a future version.'
        TraceView.logger.warn "[traceview/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      TraceView::API.send(sym, *args, &blk)
    end
  end


  #
  # Support for Oboe::Config calls
  #
  module Config
    extend ::TraceView::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args)
      # Notify of deprecation only once
      unless @deprecated_notified
        TraceView.logger.warn "[traceview/warn] Note that Oboe::Config has been renamed to TraceView::Config. (#{sym}:#{args})"
        TraceView.logger.warn '[traceview/warn] Oboe::Config will be deprecated in a future version.'
        TraceView.logger.warn "[traceview/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      TraceView::Config.send(sym, *args)
    end
  end

  #
  # Support for legacy Oboe::Ruby.load calls
  #
  module Ruby
    extend ::TraceView::ThreadLocal
    thread_local :deprecation_notified

    def self.method_missing(sym, *args)
      # Notify of deprecation only once
      unless @deprecated_notified
        TraceView.logger.warn "[traceview/warn] Note that Oboe::Ruby has been renamed to TraceView::Ruby. (#{sym}:#{args})"
        TraceView.logger.warn '[traceview/warn] Oboe::Ruby will be deprecated in a future version.'
        TraceView.logger.warn "[traceview/warn] Caller: #{Kernel.caller[0]}"
        @deprecated_notified = true
      end
      TraceView::Ruby.send(sym, *args)
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
    include TraceViewMethodProfiling::ClassMethods
  end
end
