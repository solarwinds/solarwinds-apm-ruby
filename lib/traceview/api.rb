# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  ##
  # This module implements the TraceView tracing API.
  # See: https://github.com/appneta/oboe-ruby#the-tracing-api
  # and/or: http://rdoc.info/gems/oboe/Oboe/API/Tracing
  module API
    def self.extend_with_tracing
      extend TraceView::API::Logging
      extend TraceView::API::Tracing
      extend TraceView::API::Profiling
      extend TraceView::API::LayerInit
    end
    extend TraceView::API::Util
  end
end
