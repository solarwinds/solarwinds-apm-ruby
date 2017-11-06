# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module RestClientRequest
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :execute, ::RestClient::Request)
      end

      ##
      # execute_with_appoptics
      #
      # The wrapper method for RestClient::Request.execute
      #
      def execute_with_appoptics(&block)
        blacklisted = AppOptics::API.blacklisted?(uri)

        unless AppOptics.tracing?
          xtrace = AppOptics::Context.toString
          @processed_headers = make_headers('X-Trace' => xtrace) if AppOptics::XTrace.valid?(xtrace) && !blacklisted
          return execute_without_appoptics(&block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:rest_client][:collect_backtraces]
          AppOptics::API.log_entry('rest-client', kvs)

          @processed_headers = make_headers('X-Trace' => AppOptics::Context.toString) unless blacklisted

          # The core rest-client call
          execute_without_appoptics(&block)
        rescue => e
          AppOptics::API.log_exception('rest-client', e)
          raise e
        ensure
          AppOptics::API.log_exit('rest-client')
        end
      end
    end
  end
end

if AppOptics::Config[:rest_client][:enabled]
  if defined?(::RestClient)
    AppOptics.logger.info '[appoptics/loading] Instrumenting rest-client' if AppOptics::Config[:verbose]
    ::AppOptics::Util.send_include(::RestClient::Request, ::AppOptics::Inst::RestClientRequest)
  end
end
