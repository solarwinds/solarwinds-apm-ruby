# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module ExconConnection
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :request, ::Excon::Connection)
        ::AppOptics::Util.method_alias(klass, :requests, ::Excon::Connection)
      end

      private

      def appoptics_collect(params)
        kvs = {}
        kvs[:IsService] = 1
        kvs[:RemoteProtocol] = ::AppOptics::Util.upcase(@data[:scheme])
        kvs[:RemoteHost] = @data[:host]

        # Conditionally log query args
        if AppOptics::Config[:excon][:log_args] && @data[:query]
          if @data[:query].is_a?(Hash)
            if RUBY_VERSION >= '1.9.2'
              kvs[:ServiceArg] = "#{@data[:path]}?#{URI.encode_www_form(@data[:query])}"
            else
              # An imperfect solution for the lack of URI.encode_www_form for Ruby versions before
              # 1.9.2.  We manually create a query string for reporting purposes only.
              query_arg = ""
              @data[:query].each_pair { |k,v| query_arg += "#{k}=#{v}?"; }
              kvs[:ServiceArg] = "#{@data[:path]}?#{query_arg.chop}"
            end
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
            methods << ::AppOptics::Util.upcase(p[:method])
          end
          kvs[:HTTPMethods] = methods.join(', ')[0..1024]
          kvs[:Pipeline] = true
        else
          kvs[:HTTPMethod] = ::AppOptics::Util.upcase(params[:method])
        end
        kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:excon][:collect_backtraces]
        kvs
      rescue => e
        AppOptics.logger.debug "[appoptics/debug] Error capturing excon KVs: #{e.message}"
        AppOptics.logger.debug e.backtrace.join('\n') if ::AppOptics::Config[:verbose]
      ensure
        return kvs
      end

      public

      def requests_with_appoptics(pipeline_params)
        responses = nil
        AppOptics::API.trace(:excon, appoptics_collect(pipeline_params)) do
          responses = requests_without_appoptics(pipeline_params)
        end
        responses
      end

      def request_with_appoptics(params={}, &block)
        # Avoid cross host tracing for blacklisted domains
        blacklisted = AppOptics::API.blacklisted?(@data[:hostname])

        # If we're not tracing, just do a fast return.
        # If making HTTP pipeline requests (ordered batched)
        # then just return as we're tracing from parent
        # <tt>requests</tt>
        if !AppOptics.tracing? || params[:pipeline]
          @data[:headers]['X-Trace'] = AppOptics::Context.toString if AppOptics::Context.isValid && !blacklisted
          return request_without_appoptics(params, &block)
        end

        begin
          response_context = nil

          kvs = appoptics_collect(params)
          kvs[:Blacklisted] = true if blacklisted

          AppOptics::API.log_entry(:excon, kvs)
          kvs.clear

          req_context = AppOptics::Context.toString
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
              AppOptics::XTrace.continue_service_context(req_context, response_context)
            end
          end

          response
        rescue => e
          AppOptics::API.log_exception(:excon, e)
          raise e
        ensure
          AppOptics::API.log_exit(:excon, kvs) unless params[:pipeline]
        end
      end
    end
  end
end

if AppOptics::Config[:excon][:enabled] && defined?(::Excon)
  ::AppOptics.logger.info '[appoptics/loading] Instrumenting excon' if AppOptics::Config[:verbose]
  ::AppOptics::Util.send_include(::Excon::Connection, ::AppOptics::Inst::ExconConnection)
end
