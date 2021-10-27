# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module ExconConnection
      include AppOpticsAPM::TraceContextHeaders

      # def self.included(klass)
      #   AppOpticsAPM::Util.method_alias(klass, :request, ::Excon::Connection)
      #   AppOpticsAPM::Util.method_alias(klass, :requests, ::Excon::Connection)
      # end

      private

      def appoptics_collect(params)
        kvs = {}
        kvs[:Spec] = 'rsc'
        kvs[:IsService] = 1

        # Conditionally log query args
        if AppOpticsAPM::Config[:excon][:log_args] && @data[:query]
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
            methods << AppOpticsAPM::Util.upcase(p[:method])
          end
          kvs[:HTTPMethods] = methods.join(',')[0..1024]
          kvs[:Pipeline] = true
        else
          kvs[:HTTPMethod] = AppOpticsAPM::Util.upcase(params[:method])
        end
        kvs
      rescue => e
        AppOpticsAPM.logger.debug "[appoptics_apm/debug] Error capturing excon KVs: #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace.join('\n') if AppOpticsAPM::Config[:verbose]
      ensure
        return kvs
      end

      public

      def requests(pipeline_params)
        responses = nil
        kvs = appoptics_collect(pipeline_params)
        AppOpticsAPM::API.trace(:excon, kvs) do
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:excon][:collect_backtraces]
          responses = super(pipeline_params)
          kvs[:HTTPStatuses] = responses.map { |r| r.status }.join(',')
        end
        responses
      end

      def request(params={}, &block)
        # Avoid cross host tracing for blacklisted domains
        blacklisted = AppOpticsAPM::API.blacklisted?(@data[:hostname] || @data[:host])

        # If we're not tracing, just do a fast return.
        # If making HTTP pipeline requests (ordered batched)
        # then just return as we're tracing from parent
        # <tt>requests</tt>
        if !AppOpticsAPM.tracing? || params[:pipeline]
          add_tracecontext_headers(@data[:headers], @data[:hostname] || @data[:host])
          return super(params, &block)
        end

        begin
          response_context = nil

          kvs = appoptics_collect(params)
          kvs[:Blacklisted] = true if blacklisted

          AppOpticsAPM::API.log_entry(:excon, kvs)
          kvs.clear

          req_context = AppOpticsAPM::Context.toString

          # The core excon call
          add_tracecontext_headers(@data[:headers], @data[:hostname] || @data[:host])
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
          AppOpticsAPM::API.log_exception(:excon, e)
          raise e
        ensure
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:excon][:collect_backtraces]
          AppOpticsAPM::API.log_exit(:excon, kvs) unless params[:pipeline]
        end
      end
    end
  end
end

if AppOpticsAPM::Config[:excon][:enabled] && defined?(Excon)
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting excon' if AppOpticsAPM::Config[:verbose]
  # AppOpticsAPM::Util.send_include(Excon::Connection, AppOpticsAPM::Inst::ExconConnection)
  Excon::Connection.prepend(AppOpticsAPM::Inst::ExconConnection)
end
