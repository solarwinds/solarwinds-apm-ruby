module Oboe
  #
  # Support for Oboe::API calls
  #
  module API
    include TraceView::API
    def self.method_missing(sym, *args, &blk)
      TraceView.logger.warn "[traceview/warn] Note that Oboe::Config has been renamed to TraceView::Config. (#{sym}:#{args})"
      TraceView::API.send(sym, *args, &blk)
    end
  end


  #
  # Support for Oboe::Config calls
  #
  module Config
    def self.method_missing(sym, *args)
      TraceView.logger.warn "[traceview/warn] Note that Oboe::Config has been renamed to TraceView::Config. (#{sym}:#{args})"
      TraceView::Config.send(sym, *args)
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

