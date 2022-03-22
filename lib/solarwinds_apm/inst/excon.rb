# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module ExconConnection
      include SolarWindsAPM::SDK::TraceContextHeaders

      private

      def sw_apm_collect(params)
        kvs = {}
        kvs[:Spec] = 'rsc'
        kvs[:IsService] = 1

        # Conditionally log query args
        if SolarWindsAPM::Config[:excon][:log_args] && @data[:query]
          if @data[:query].is_a?(Hash)
            service_arg = "#{@data[:path]}?#{URI.encode_www_form(@data[:query])}"
          else
            service_arg = "#{@data[:path]}?#{@data[:query]}"
          end
        else
          service_arg = @data[:path]
        end
        kvs[:RemoteURL] = "#{@data[:scheme]}://#{@data[:host]}:#{@data[:port]}#{service_arg}"

        # In the case of HTTP pipelining, params could be an array of
        # request hashes.
        if params.is_a?(Array)
          methods = []
          params.each do |p|
            methods << SolarWindsAPM::Util.upcase(p[:method])
          end
          kvs[:HTTPMethods] = methods.join(',')[0..1024]
          kvs[:Pipeline] = true
        else
          kvs[:HTTPMethod] = SolarWindsAPM::Util.upcase(params[:method])
        end
        kvs
      rescue => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] Error capturing excon KVs: #{e.message}"
        SolarWindsAPM.logger.debug e.backtrace.join('\n') if SolarWindsAPM::Config[:verbose]
      ensure
        return kvs
      end

      public

      def requests(pipeline_params)
        responses = nil
        kvs = sw_apm_collect(pipeline_params)
        SolarWindsAPM::SDK.trace(:excon, kvs: kvs) do
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:excon][:collect_backtraces]
          responses = super(pipeline_params)
          kvs[:HTTPStatuses] = responses.map { |r| r.status }.join(',')
        end
        responses
      end

      def request(params = {}, &block)
        # If we're not tracing, just do a fast return.
        # If making HTTP pipeline requests (ordered batched)
        # then just return as we're tracing from parent
        # <tt>requests</tt>
        if !SolarWindsAPM.tracing? || params[:pipeline]
          add_tracecontext_headers(@data[:headers])
          return super(params, &block)
        end

        begin
          response_context = nil

          kvs = sw_apm_collect(params)

          SolarWindsAPM::API.log_entry(:excon, kvs)
          kvs.clear

          req_context = SolarWindsAPM::Context.toString

          # The core excon call
          add_tracecontext_headers(@data[:headers])
          response = super(params, &block)

          # excon only passes back a hash (datum) for HTTP pipelining...
          # In that case, we should never arrive here but for the OCD, double check
          # the datatype before trying to extract pertinent info
          if response.is_a?(Excon::Response)
            kvs[:HTTPStatus] = response.status

            # If we get a redirect, report the location header
            if ((300..308).to_a.include? response.status.to_i) && response.headers.key?('Location')
              kvs[:Location] = response.headers['Location']
            end
          end

          response
        rescue => e
          SolarWindsAPM::API.log_exception(:excon, e)
          raise e
        ensure
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:excon][:collect_backtraces]
          SolarWindsAPM::API.log_exit(:excon, kvs) unless params[:pipeline]
        end
      end
    end
  end
end

if SolarWindsAPM::Config[:excon][:enabled] && defined?(Excon)
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting excon' if SolarWindsAPM::Config[:verbose]
  Excon::Connection.prepend(SolarWindsAPM::Inst::ExconConnection)
end
