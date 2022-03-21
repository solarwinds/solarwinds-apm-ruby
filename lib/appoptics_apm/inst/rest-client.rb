# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module RestClientRequest
      include SolarWindsAPM::SDK::TraceContextHeaders

      ##
      # execute
      #
      # The wrapper method for RestClient::Request.execute
      #
      def execute(&block)
        unless SolarWindsAPM.tracing?
          add_tracecontext_headers(@processed_headers)
          return super(&block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:rest_client][:collect_backtraces]
          SolarWindsAPM::API.log_entry('rest-client', kvs)

          add_tracecontext_headers(@processed_headers)

          # The core rest-client call
          super(&block)
        rescue => e
          SolarWindsAPM::API.log_exception('rest-client', e)
          raise e
        ensure
          SolarWindsAPM::API.log_exit('rest-client')
        end
      end
    end
  end
end

if defined?(RestClient) && SolarWindsAPM::Config[:rest_client][:enabled]
  SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting rest-client' if SolarWindsAPM::Config[:verbose]
  RestClient::Request.prepend(SolarWindsAPM::Inst::RestClientRequest)
end
