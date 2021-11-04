# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module RestClientRequest
      include AppOpticsAPM::TraceContextHeaders

      ##
      # execute
      #
      # The wrapper method for RestClient::Request.execute
      #
      def execute(&block)
        unless AppOpticsAPM.tracing?
          add_tracecontext_headers(@processed_headers)
          return super(&block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:rest_client][:collect_backtraces]
          AppOpticsAPM::API.log_entry('rest-client', kvs)

          add_tracecontext_headers(@processed_headers)

          # The core rest-client call
          super(&block)
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

if defined?(RestClient) && AppOpticsAPM::Config[:rest_client][:enabled]
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting rest-client' if AppOpticsAPM::Config[:verbose]
  RestClient::Request.prepend(AppOpticsAPM::Inst::RestClientRequest)
end
