####
# noop version of AppOpticsAPM::Context
#
#

module AppOpticsAPM
  module Context

    ##
    # noop version of :toString
    # toString would return the current context (xtrace) as string
    #
    # the noop version returns an empty string
    #
    def self.toString
      '2B0000000000000000000000000000000000000000000000000000000000'
    end

    ##
    # noop version of :clear
    #
    def self.clear

    end
  end
end