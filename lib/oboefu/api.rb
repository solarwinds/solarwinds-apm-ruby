# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module API
    def self.extend_with_tracing
      extend Oboe::API::Logging
      extend Oboe::API::Tracing
    end

    def self.extend_with_noop
      extend Oboe::API::LoggingNoop
      extend Oboe::API::TracingNoop
    end
    
    extend Oboe::API::Util
  end
end
