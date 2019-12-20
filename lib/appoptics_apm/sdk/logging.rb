# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.
#

module AppOpticsAPM
  module SDK
    module Logging

      # Log an information event in the current span
      #
      # a possible use-case is to collect extra information during the execution of a request
      #
      # === Arguments:
      # * +opts+   - (optional) hash containing key/value pairs that will be reported with this span.
      #
      def log_info(opts)
        AppOpticsAPM::API.log_info(AppOpticsAPM.layer, opts)
      end

      # Log an exception/error event in the current span
      #
      # this may be helpful to track problems when an exception is rescued
      #
      # === Arguments:
      # * +exception+ - an exception, must respond to :message and :backtrace
      # * +opts+      - (optional) hash containing key/value pairs that will be reported with this span.
      #
      def log_exception(exception, opts = {})
        AppOpticsAPM::API.log_exception(AppOpticsAPM.layer, exception, opts)
      end

    end

    extend Logging

  end
end
