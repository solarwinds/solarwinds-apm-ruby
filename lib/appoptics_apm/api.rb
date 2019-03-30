# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  module API
    extend AppOpticsAPM::API::Logging
    extend AppOpticsAPM::API::Metrics
    extend AppOpticsAPM::API::Profiling
    extend AppOpticsAPM::API::LayerInit
    extend AppOpticsAPM::API::Util

    require_relative './sdk/tracing'
    require_relative './sdk/custom_metrics'
    require_relative './sdk/current_trace'

    extend AppOpticsAPM::SDK::Tracing
    extend AppOpticsAPM::SDK::CustomMetrics
    extend AppOpticsAPM::API::Tracing
  end
end
