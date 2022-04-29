# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

# Test script used to check if a newly created gem installs and connects to
# the collector
# requires env vars:
# - SW_APM_SERVICE_KEY
# - SW_APM_COLLECTOR (optional if the key is for production)

require 'solarwinds_apm'

unless SolarWindsAPM::SDK.solarwinds_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end

SolarWindsAPM.support_report

# no profiling yet for NH, but it shouldn't choke on Profiling.run
SolarWindsAPM::Config[:profiling] = :disabled

SolarWindsAPM::SDK.start_trace("install_test_profiling") do
  SolarWindsAPM::Profiling.run do
    10.times do
      [9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort
      # sleep 0.2 # maybe turn back on when profiling
    end
    puts "Looking good so far :)"  # this will show up in the log of github actions
  end
end
