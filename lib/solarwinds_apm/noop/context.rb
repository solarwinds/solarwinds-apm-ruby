# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

####
# noop version of SolarWindsAPM::Context
#
#

module SolarWindsAPM
  module Context

    ##
    # noop version of :toString
    # toString would return the current trace context as string
    #
    def self.toString
      '00-00000000000000000000000000000000-0000000000000000-00'
    end

    ##
    # noop version of :clear
    #
    def self.clear
    end
  end
end
