# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'benchmark/ips'
require_relative '../minitest_helper'


# compare logging when testing for loaded versus tracing?
ENV['APPOPTICS_GEM_VERBOSE'] = 'false'

n = 1000

Benchmark.ips do |x|
  x.config(:time => 10, :warmup => 2)

  # x.report('tracing_f') do
  #   AppOptics.loaded = false
  #   AppOptics::Config[:tracing_mode] = 'never'
  #   AppOptics::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')
  #   n.times do
  #     AppOptics.tracing?
  #   end
  # end
  # x.report('tracing_n') do
  #   AppOptics.loaded = true
  #   AppOptics::Config[:tracing_mode] = 'never'
  #   AppOptics::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')
  #   n.times do
  #     AppOptics.tracing?
  #   end
  # end

  x.report('tracing_tf') do
    AppOptics.loaded = true
    AppOptics::Config[:tracing_mode] = 'always'
    AppOptics::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')
    n.times do
      AppOptics.tracing?
    end
  end
  x.report('tracing_tt') do
    AppOptics.loaded = true
    AppOptics::Config[:tracing_mode] = 'always'
    AppOptics::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')
    n.times do
      AppOptics.tracing?
      AppOptics.tracing?
    end
  end

  x.compare!
end


