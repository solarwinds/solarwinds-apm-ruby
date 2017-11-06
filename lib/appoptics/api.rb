# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  ##
  # This module implements the AppOptics tracing API.
  # See: https://github.com/tracelytics/ruby-appoptics#the-tracing-api
  # and/or: http://rdoc.info/gems/appoptics/AppOptics/API/Tracing
  module API
    def self.extend_with_tracing
      extend AppOptics::API::Logging
      extend AppOptics::API::Tracing
      extend AppOptics::API::Profiling
      extend AppOptics::API::LayerInit
    end
    extend AppOptics::API::Util
  end
end
