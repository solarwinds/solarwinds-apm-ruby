# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  ##
  # This module implements the TraceView tracing API.
  # See: https://github.com/tracelytics/ruby-traceview#the-tracing-api
  # and/or: http://rdoc.info/gems/traceview/TraceView/API/Tracing
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
