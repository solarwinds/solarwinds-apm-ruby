#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module API
    ##
    # Provides methods related to layer initialization and reporting
    module LayerInit #:nodoc:
      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer = :rack) #:nodoc:
        # Don't send __Init in test or if AppOpticsAPM
        # isn't fully loaded (e.g. missing c-extension)
        return if ENV.key?('APPOPTICS_GEM_TEST') || !AppOpticsAPM.loaded

        platform_info = AppOpticsAPM::Util.build_init_report
        log_init(layer, platform_info)
      end

    end
  end
end
