# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

# Test script used to check if a newly created gem installs and connects to
# the collector
# requires env vars:
# - SW_APM_SERVICE_KEY
# - SW_APM_COLLECTOR (optional if the key is for production)

require 'solarwinds_apm'
SolarWindsAPM.support_report
exit 1 unless SolarWindsAPM.reporter

SolarWindsAPM::Config[:profiling] = :enabled

SolarWindsAPM::SDK.start_trace("install_test_profiling") do
  SolarWindsAPM::Profiling.run do
    10.times do
      [9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort
      sleep 0.2
    end
  end
end
