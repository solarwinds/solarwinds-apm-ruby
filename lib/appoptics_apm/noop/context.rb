####
# noop version of AppOpticsAPM::Context
#
#

module AppOpticsAPM
  module Context

    ##
    # noop version of toString
    # toString would return the current context (xtrace) as string
    #
    # the noop version returns an empty string
    #
    def self.toString
      ''
    end
  end
end