# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ExconConnection
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :request, ::Excon::Connection)
      end

      def oboe_collect(params)
          kvs = {}
          kvs['IsService'] = 1
          kvs['RemoteProtocol'] = @data[:scheme].upcase
          kvs['RemoteHost'] = @data[:hostname]
          kvs['ServiceArg'] = @data[:path]
          kvs['HTTPMethod'] = params[:method].upcase
          kvs['Pipelined'] = params[:pipeline]
          kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:excon][:collect_backtraces]
          kvs
      rescue => e
        Oboe.logger.debug "[oboe/debug] Error capturing excon KVs: #{e.message}"
        Oboe.logger.debug e.backtrace.join('\n') if ::Oboe::Config[:verbose]
      end

      def request_with_oboe(params={}, &block)
        # If we're not tracing, just do a fast return.
        if !Oboe.tracing?
          return request_without_oboe(params, &block)
        end

        begin
          response_context = nil

          # Avoid cross host tracing for blacklisted domains
          blacklisted = Oboe::API.blacklisted?(@data[:hostname])

          req_context = Oboe::Context.toString()
          @data[:headers]['X-Trace'] = req_context unless blacklisted

          kvs = oboe_collect(params)
          kvs['Blacklisted'] = true if blacklisted

          Oboe::API.log_entry('excon', kvs)
          kvs.clear

          # The core excon call
          response = request_without_oboe(params, &block)

          if response.is_a?(Hash)
            response_context = response[:headers]["X-Trace"]
          else
            response_context = response.headers['X-Trace']
            kvs['HTTPStatus'] = response.status

            # If we get a redirect, report the location header
            if ((300..308).to_a.include? response.status.to_i) && response.headers.key?("Location")
              kvs["Location"] = response.headers["Location"]
            end
          end

          if response_context && !blacklisted
            Oboe::XTrace.continue_service_context(req_context, response_context)
          end

          response
        rescue => e
          Oboe::API.log_exception('excon', e)
          raise e
        ensure
          Oboe::API.log_exit('excon', kvs)
        end
      end
    end
  end
end

if Oboe::Config[:excon][:enabled] && defined?(::Excon)
  ::Oboe.logger.info '[oboe/loading] Instrumenting excon' if Oboe::Config[:verbose]
  ::Oboe::Util.send_include(::Excon::Connection, ::Oboe::Inst::ExconConnection)
end
