# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  ##
  # The current version of the gem.  Used mainly by
  # appoptics.gemspec during gem build process
  module Version
    MAJOR = 4
    MINOR = 0
    PATCH = 0
    BUILD = 'pre11'

    STRING = [MAJOR, MINOR, PATCH, BUILD].compact.join('.')
  end
end
