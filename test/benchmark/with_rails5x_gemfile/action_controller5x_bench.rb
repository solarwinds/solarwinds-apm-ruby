# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'benchmark/ips'
require 'benchmark/memory'
require_relative '../../minitest_helper'

# compare logging when testing for loaded versus tracing?
ENV['APPOPTICS_GEM_VERBOSE'] = 'false'
ENV['DBTYPE'] = "postgresql" unless ENV['DBTYPE']

def dostuff(uri)
  n = 100
  n.times do
    Net::HTTP.get_response(uri)
  end
end


Benchmark.memory do |x|
  AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false
  # x.config(:time => 20, :warmup => 20, :iterations => 3)
  uri = URI.parse('http://127.0.0.1:8140/hello/world')

  x.report('controller_A') do
    ENV['TEST_AB'] = 'A'
    AppOpticsAPM.loaded = true
    AppOpticsAPM::Config[:tracing_mode] = 'always'
    AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

    dostuff(uri)
  end
  x.report('controller_B') do
    ENV['TEST_AB'] = 'B'
    AppOpticsAPM.loaded = true
    AppOpticsAPM::Config[:tracing_mode] = 'always'
    AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

    dostuff(uri)
  end

  x.compare!
end
