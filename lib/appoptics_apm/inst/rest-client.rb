# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module RestClientRequest
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :execute, ::RestClient::Request)
      end

      ##
      # execute_with_appoptics
      #
      # The wrapper method for RestClient::Request.execute
      #
      def execute_with_appoptics(&block)
        blacklisted = AppOpticsAPM::API.blacklisted?(uri)

        unless AppOpticsAPM.tracing?
          xtrace = AppOpticsAPM::Context.toString
          @processed_headers = make_headers('X-Trace' => xtrace) if AppOpticsAPM::XTrace.valid?(xtrace) && !blacklisted
          return execute_without_appoptics(&block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:rest_client][:collect_backtraces]
          AppOpticsAPM::API.log_entry('rest-client', kvs)

          @processed_headers = make_headers('X-Trace' => AppOpticsAPM::Context.toString) unless blacklisted

          # The core rest-client call
          execute_without_appoptics(&block)
        rescue => e
          AppOpticsAPM::API.log_exception('rest-client', e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit('rest-client')
        end
      end
    end
  end
end

if AppOpticsAPM::Config[:rest_client][:enabled]
  if defined?(::RestClient)
    AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting rest-client' if AppOpticsAPM::Config[:verbose]
    ::AppOpticsAPM::Util.send_include(::RestClient::Request, ::AppOpticsAPM::Inst::RestClientRequest)
  end
end
