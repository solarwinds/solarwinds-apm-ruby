# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module HTTPClient

      def appoptics_collect(method, uri, query = nil)
        kvs = {}
        kvs[:Spec] = 'rsc'
        kvs[:IsService] = 1

        # Conditionally log URL query params
        # Because of the hook points, the query arg can come in under <tt>query</tt>
        # or as a part of <tt>uri</tt> (not both).  Here we handle both cases.
        if AppOpticsAPM::Config[:httpclient][:log_args]
          if query
            kvs[:RemoteURL] = uri.to_s + '?' + AppOpticsAPM::Util.to_query(query)
          else
            kvs[:RemoteURL] = uri.to_s
          end
        else
          kvs[:RemoteURL] = uri.to_s.split('?').first
        end

        kvs[:HTTPMethod] = AppOpticsAPM::Util.upcase(method)
        kvs
      rescue => e
        AppOpticsAPM.logger.debug "[appoptics_apm/debug] Error capturing httpclient KVs: #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace.join('\n') if AppOpticsAPM::Config[:verbose]
      ensure
        return kvs
      end

      def do_request(method, uri, query, body, header, &block)
        # Avoid cross host tracing for blacklisted domains
        blacklisted = AppOpticsAPM::API.blacklisted?(uri.hostname)

        # If we're not tracing, just do a fast return.
        unless AppOpticsAPM.tracing?
          add_trace_header(header) unless blacklisted
          return super(method, uri, query, body, header, &block)
        end

        begin
          req_context = nil
          response_context = nil

          kvs = appoptics_collect(method, uri, query)
          kvs[:Blacklisted] = true if blacklisted

          AppOpticsAPM::API.log_entry(:httpclient, kvs)
          kvs.clear
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:httpclient][:collect_backtraces]

          add_trace_header(header) unless blacklisted

          # The core httpclient call
          response = super(method, uri, query, body, header, &block)
          kvs[:HTTPStatus] = response.status_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response.status.to_i) && response.headers.key?('Location')
            kvs[:Location] = response.headers['Location']
          end

          response
        rescue => e
          AppOpticsAPM::API.log_exception(:httpclient, e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit(:httpclient, kvs)
        end
      end

      def do_request_async(method, uri, query, body, header)
        add_trace_header(header) unless AppOpticsAPM::API.blacklisted?(uri.hostname)
        super(method, uri, query, body, header)
      end

      def do_get_stream(req, proxy, conn)
        unless req.header['traceparent'].empty?
          xtrace = AppOpticsAPM::TraceContext.w3c_to_ao_trace(req.header['traceparent'].first)
          AppOpticsAPM::Context.fromString(xtrace)
        end
        # Avoid cross host tracing for blacklisted domains
        uri = req.http_header.request_uri
        blacklisted = AppOpticsAPM::API.blacklisted?(uri.hostname)

        unless AppOpticsAPM.tracing?
          req.header.delete('traceparent') if blacklisted
          return super(req, proxy, conn)
        end

        begin
          req_context = nil
          method = req.http_header.request_method

          kvs = appoptics_collect(method, uri)
          kvs[:Blacklisted] = true if blacklisted
          kvs[:Async] = 1

          AppOpticsAPM::API.log_entry(:httpclient, kvs)
          kvs.clear
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:httpclient][:collect_backtraces]

          if blacklisted
            req.header.delete('traceparent')
            req.header.delete('tracestate')
          else
            add_trace_header(req.header)
          end

          # The core httpclient call
          result = super(req, proxy, conn)

          # Older HTTPClient < 2.6.0 returns HTTPClient::Connection
          if result.is_a?(::HTTP::Message)
            response = result
          else
            response = conn.pop
          end

          kvs[:HTTPStatus] = response.status_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response.status.to_i) && response.headers.key?('Location')
            kvs[:Location] = response.headers['Location']
          end

          # Older HTTPClient < 2.6.0 returns HTTPClient::Connection
          conn.push response if result.is_a?(::HTTPClient::Connection)
          result
        rescue => e
          AppOpticsAPM::API.log_exception(:httpclient, e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit(:httpclient, kvs)
        end
      end

      private

      def add_trace_header(headers)
        traceparent, tracestate = w3c_context

        # Be aware of various ways to call/use httpclient
        if headers.is_a?(Array)
          headers.delete_if { |kv| kv[0] =~ /^([Tt]raceparent|[Tt]racestate)$/ }
          headers.push ['traceparent', traceparent] if traceparent
          headers.push ['tracestate', tracestate] if tracestate
        elsif headers.is_a?(Hash)
          headers['traceparent'] = traceparent if traceparent
          headers['tracestate'] = tracestate  if tracestate
        elsif headers.is_a? HTTP::Message::Headers
          headers.set('traceparent', traceparent) if traceparent
          headers.set('tracestate', tracestate) if tracestate
        end
      end

      def w3c_context
        context = AppOpticsAPM::Context.toString

        if AppOpticsAPM::XTrace.valid?(context)
          traceparent = AppOpticsAPM::TraceContext.ao_to_w3c_trace(context)
          parent_id_flags = AppOpticsAPM::TraceParent.edge_id_flags(traceparent)
          tracestate = AppOpticsAPM::TraceState.add_kv(AppOpticsAPM.trace_context&.tracestate, parent_id_flags)
          return [traceparent, tracestate]
        elsif AppOpticsAPM.trace_context && AppOpticsAPM.trace_context.traceparent
          return [AppOpticsAPM.trace_context.traceparent, AppOpticsAPM.trace_context.tracestate]
        end

        [nil, nil]
      end

    end
  end
end

if AppOpticsAPM::Config[:httpclient][:enabled] && defined?(HTTPClient)
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting httpclient' if AppOpticsAPM::Config[:verbose]
  HTTPClient.prepend(AppOpticsAPM::Inst::HTTPClient)
end
