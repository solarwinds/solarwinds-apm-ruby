# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  ##
  # The current version of the gem. Used mainly by
  # solarwinds_apm.gemspec during gem build process
  module Version
    MAJOR  = 0 # breaking,
    MINOR  = 0 # feature,
    PATCH  = 1 # fix => BFF
    PRE    = 0 # for pre-releases into packagecloud,
               # set to nil for production releases into rubygems

    STRING = [MAJOR, MINOR, PATCH, PRE].compact.join('.')
  end
end
