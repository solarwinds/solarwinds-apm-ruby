# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

# Test script used to check if a newly created gem installs and connects to
# the collector
# requires env vars:
# - APPOPTICS_SERVICE_KEY
# - APPOPTICS_COLLECTOR (optional if the kye is for production)

require 'appoptics_apm'
AppOpticsAPM.support_report
exit 1 unless AppOpticsAPM.reporter
