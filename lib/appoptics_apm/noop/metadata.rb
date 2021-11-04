# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

####
# noop version of AppOpticsAPM::Metadata
#
#

module AppOpticsAPM
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

    def padZeros
      nil
    end
  end
end
