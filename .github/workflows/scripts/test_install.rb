# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

# Test script used to check if a newly created gem installs and connects to
# the collector
# requires env vars:
# - APPOPTICS_SERVICE_KEY
# - APPOPTICS_COLLECTOR (optional if the key is for production)

require 'appoptics_apm'
AppOpticsAPM.support_report
exit 1 unless AppOpticsAPM.reporter

AppOpticsAPM::Config[:profiling] = :enabled

AppOpticsAPM::SDK.start_trace("install_test_profiling") do
  AppOpticsAPM::Profiling.run do
    10.times do
      [9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort
      sleep 0.2
    end
  end
end
