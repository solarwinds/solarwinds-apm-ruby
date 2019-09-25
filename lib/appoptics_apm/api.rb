# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  module API
    extend AppOpticsAPM::API::Logging
    extend AppOpticsAPM::API::Metrics
    extend AppOpticsAPM::API::LayerInit
    extend AppOpticsAPM::API::Util

    require_relative './sdk/tracing'
    require_relative './sdk/custom_metrics'
    require_relative './sdk/current_trace'
    require_relative './sdk/logging' # to make sure it is loaded <- not very elegant

    extend AppOpticsAPM::SDK::Tracing
    extend AppOpticsAPM::SDK::CustomMetrics
    extend AppOpticsAPM::API::Tracing
  end
end
