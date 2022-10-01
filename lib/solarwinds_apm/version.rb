# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  ##
  # The current version of the gem. Used mainly by
  # solarwinds_apm.gemspec during gem build process
  module Version
    MAJOR  = 5 # breaking,
    MINOR  = 1 # feature,
    PATCH  = 0 # fix => BFF
    PRE    = nil # for pre-releases into packagecloud, set to nil for production releases into rubygems

    STRING = [MAJOR, MINOR, PATCH, PRE].compact.join('.')
  end
end
