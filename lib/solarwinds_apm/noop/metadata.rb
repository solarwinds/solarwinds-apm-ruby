# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

####
# noop version of SolarWindsAPM::Metadata
#
#

module SolarWindsAPM
  class Metadata

    ##
    # noop version of :makeRandom
    #
    # needs to return an object that responds to :isValid
    #
    def self.makeRandom
      Metadata.new
    end

    def isValid
      false
    end
  end
end
