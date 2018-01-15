# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  # This module implements the AppOpticsAPM tracing API.
  # See: https://github.com/librato/ruby-appoptics#the-tracing-api
  # and/or: http://rdoc.info/gems/appoptics_apm/AppOpticsAPM/API/Tracing
  module API
    def self.extend_with_tracing
      extend AppOpticsAPM::API::Logging
      extend AppOpticsAPM::API::Tracing
      extend AppOpticsAPM::API::Profiling
      extend AppOpticsAPM::API::LayerInit
    end
    extend AppOpticsAPM::API::Util
  end
end
