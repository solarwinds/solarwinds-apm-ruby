# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  ##
  # This module implements the TraceView tracing API.
  # See: https://github.com/appneta/oboe-ruby#the-tracing-api
  # and/or: http://rdoc.info/gems/oboe/Oboe/API/Tracing
  module API
    def self.extend_with_tracing
      extend Oboe::API::Logging
      extend Oboe::API::Tracing
      extend Oboe::API::Profiling
      extend Oboe::API::LayerInit
    end
    extend Oboe::API::Util
  end
end
