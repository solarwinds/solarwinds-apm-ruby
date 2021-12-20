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
      # * +kvs+   - (optional) hash containing key/value pairs that will be reported with this span.
      #
      def log_info(kvs)
        AppOpticsAPM::API.log_info(AppOpticsAPM.layer, kvs)
      end

      # Log an exception/error event in the current span
      #
      # this may be helpful to track problems when an exception is rescued
      #
      # === Arguments:
      # * +exception+ - an exception, must respond to :message and :backtrace
      # * +kvs+      - (optional) hash containing key/value pairs that will be reported with this span.
      #
      def log_exception(exception, kvs = {})
        AppOpticsAPM::API.log_exception(AppOpticsAPM.layer, exception, kvs)
      end

    end

    extend Logging

  end
end
