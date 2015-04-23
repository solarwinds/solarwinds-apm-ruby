# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ExconConnection
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :request, ::Excon::Connection)
        ::Oboe::Util.method_alias(klass, :requests, ::Excon::Connection)
      end

      def oboe_collect(params)
        kvs = {}
        kvs['IsService'] = 1
        kvs['RemoteProtocol'] = ::Oboe::Util.upcase(@data[:scheme])
        kvs['RemoteHost'] = @data[:host]
        kvs['ServiceArg'] = @data[:path]

        if params.is_a?(Array)
          methods = []
          params.each do |p|
            methods << ::Oboe::Util.upcase(p[:method])
          end
          kvs['HTTPMethods'] = methods.join(', ')[0..1024]
          kvs['Pipeline'] = true
        else
          kvs['HTTPMethod'] = ::Oboe::Util.upcase(params[:method])
        end
        kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:excon][:collect_backtraces]
        kvs
      rescue => e
        Oboe.logger.debug "[oboe/debug] Error capturing excon KVs: #{e.message}"
        Oboe.logger.debug e.backtrace.join('\n') if ::Oboe::Config[:verbose]
      end

      def requests_with_oboe(pipeline_params)
        responses = nil
        Oboe::API.trace('excon', oboe_collect(pipeline_params)) do
          responses = requests_without_oboe(pipeline_params)
        end
        responses
      end

      def request_with_oboe(params={}, &block)
        # If we're not tracing, just do a fast return.
        # If making HTTP pipeline requests (ordered batched)
        # then just return as we're tracing from parent
        # <tt>requests</tt>
        if !Oboe.tracing? || params[:pipeline]
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

          # excon only passes back a hash (datum) for HTTP pipelining...
          # In that case, we should never arrive here but for the OCD, double check
          # the datatype before trying to extract pertinent info
          if response.is_a?(Excon::Response)
            response_context = response.headers['X-Trace']
            kvs['HTTPStatus'] = response.status

            # If we get a redirect, report the location header
            if ((300..308).to_a.include? response.status.to_i) && response.headers.key?("Location")
              kvs["Location"] = response.headers["Location"]
            end

            if response_context && !blacklisted
              Oboe::XTrace.continue_service_context(req_context, response_context)
            end
          end

          response
        rescue => e
          Oboe::API.log_exception('excon', e)
          raise e
        ensure
          Oboe::API.log_exit('excon', kvs) unless params[:pipeline]
        end
      end
    end
  end
end

if Oboe::Config[:excon][:enabled] && defined?(::Excon)
  ::Oboe.logger.info '[oboe/loading] Instrumenting excon' if Oboe::Config[:verbose]
  ::Oboe::Util.send_include(::Excon::Connection, ::Oboe::Inst::ExconConnection)
end
