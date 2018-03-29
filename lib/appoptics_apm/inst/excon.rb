# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module ExconConnection
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :request, ::Excon::Connection)
        ::AppOpticsAPM::Util.method_alias(klass, :requests, ::Excon::Connection)
      end

      private

      def appoptics_collect(params)
        kvs = {}
        kvs[:IsService] = 1
        kvs[:RemoteProtocol] = ::AppOpticsAPM::Util.upcase(@data[:scheme])
        kvs[:RemoteHost] = @data[:host]

        # Conditionally log query args
        if AppOpticsAPM::Config[:excon][:log_args] && @data[:query]
          if @data[:query].is_a?(Hash)
            kvs[:ServiceArg] = "#{@data[:path]}?#{URI.encode_www_form(@data[:query])}"
          else
            kvs[:ServiceArg] = "#{@data[:path]}?#{@data[:query]}"
          end
        else
          kvs[:ServiceArg] = @data[:path]
        end

        # In the case of HTTP pipelining, params could be an array of
        # request hashes.
        if params.is_a?(Array)
          methods = []
          params.each do |p|
            methods << ::AppOpticsAPM::Util.upcase(p[:method])
          end
          kvs[:HTTPMethods] = methods.join(', ')[0..1024]
          kvs[:Pipeline] = true
        else
          kvs[:HTTPMethod] = ::AppOpticsAPM::Util.upcase(params[:method])
        end
        kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:excon][:collect_backtraces]
        kvs
      rescue => e
        AppOpticsAPM.logger.debug "[appoptics_apm/debug] Error capturing excon KVs: #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace.join('\n') if ::AppOpticsAPM::Config[:verbose]
      ensure
        return kvs
      end

      public

      def requests_with_appoptics(pipeline_params)
        responses = nil
        AppOpticsAPM::API.trace(:excon, appoptics_collect(pipeline_params)) do
          responses = requests_without_appoptics(pipeline_params)
        end
        responses
      end

      def request_with_appoptics(params={}, &block)
        # Avoid cross host tracing for blacklisted domains
        blacklisted = AppOpticsAPM::API.blacklisted?(@data[:hostname] || @data[:host])

        # If we're not tracing, just do a fast return.
        # If making HTTP pipeline requests (ordered batched)
        # then just return as we're tracing from parent
        # <tt>requests</tt>
        if !AppOpticsAPM.tracing? || params[:pipeline]
          @data[:headers]['X-Trace'] = AppOpticsAPM::Context.toString if AppOpticsAPM::Context.isValid && !blacklisted
          return request_without_appoptics(params, &block)
        end

        begin
          response_context = nil

          kvs = appoptics_collect(params)
          kvs[:Blacklisted] = true if blacklisted

          AppOpticsAPM::API.log_entry(:excon, kvs)
          kvs.clear

          req_context = AppOpticsAPM::Context.toString
          @data[:headers]['X-Trace'] = req_context unless blacklisted

          # The core excon call
          response = request_without_appoptics(params, &block)

          # excon only passes back a hash (datum) for HTTP pipelining...
          # In that case, we should never arrive here but for the OCD, double check
          # the datatype before trying to extract pertinent info
          if response.is_a?(Excon::Response)
            response_context = response.headers['X-Trace']
            kvs[:HTTPStatus] = response.status

            # If we get a redirect, report the location header
            if ((300..308).to_a.include? response.status.to_i) && response.headers.key?('Location')
              kvs[:Location] = response.headers['Location']
            end

            if response_context && !blacklisted
              AppOpticsAPM::XTrace.continue_service_context(req_context, response_context)
            end
          end

          response
        rescue => e
          AppOpticsAPM::API.log_exception(:excon, e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit(:excon, kvs) unless params[:pipeline]
        end
      end
    end
  end
end

if AppOpticsAPM::Config[:excon][:enabled] && defined?(::Excon)
  ::AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting excon' if AppOpticsAPM::Config[:verbose]
  ::AppOpticsAPM::Util.send_include(::Excon::Connection, ::AppOpticsAPM::Inst::ExconConnection)
end
