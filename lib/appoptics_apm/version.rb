# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  # The current version of the gem.  Used mainly by
  # appoptics_apm.gemspec during gem build process
  module Version
    MAJOR = 0  # breaking,
    MINOR = 1 # feature,
    PATCH = 0  # fix => BFF
    PRE   = "ghtest11"

    STRING = [MAJOR, MINOR, PATCH, PRE].compact.join('.')
  end
end
