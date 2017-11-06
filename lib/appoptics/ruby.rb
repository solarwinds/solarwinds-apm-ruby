# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  ##
  # This module provides a method to manually initialize the
  # Ruby instrumentation.  Normally this is done by detecting
  # frameworks at load time and inserting initialization hooks.
  module Ruby
    class << self
      def initialize
        load
      end

      ##
      # The core method to load Ruby instrumentation.  Call this
      # from raw Ruby scripts or in Ruby applications where a
      # supported framework isn't being used.  Supported frameworks
      # will instead be detected at load time and initialization is
      # automatic.
      def load
        # In case some apps call this manually, make sure
        # that the gem is fully loaded and not in no-op
        # mode (e.g. on unsupported platforms etc.)
        if AppOptics.loaded
          AppOptics::Inst.load_instrumentation
        end
      end
    end
  end
end

if AppOptics.loaded && !AppOptics.framework?
  ::AppOptics::Ruby.load
end
