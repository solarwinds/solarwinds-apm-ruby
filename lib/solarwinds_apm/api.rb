# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM

  module API
    extend SolarWindsAPM::API::Logging
    extend SolarWindsAPM::API::Metrics
    extend SolarWindsAPM::API::LayerInit
    extend SolarWindsAPM::API::Util

    require_relative './sdk/trace_context_headers'
    require_relative './sdk/tracing'
    require_relative './sdk/custom_metrics'
    require_relative './sdk/current_trace_info'
    require_relative './sdk/logging' # to make sure it is loaded <- not very elegant

    extend SolarWindsAPM::SDK::Tracing
    extend SolarWindsAPM::SDK::CustomMetrics
  end
end
