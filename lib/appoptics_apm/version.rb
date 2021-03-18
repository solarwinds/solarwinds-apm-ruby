# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  # The current version of the gem.  Used mainly by
  # appoptics_apm.gemspec during gem build process
  module Version
    MAJOR = 4  # breaking,
    MINOR = 12 # feature,
    PATCH = 2  # fix => BFF
    PRE   = "ghtest2"

    STRING = [MAJOR, MINOR, PATCH, PRE].compact.join('.')
  end
end
