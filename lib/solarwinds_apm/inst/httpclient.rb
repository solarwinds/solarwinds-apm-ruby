# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module HTTPClient

      def appoptics_collect(method, uri, query = nil)
        kvs = {}
        kvs[:Spec] = 'rsc'
        kvs[:IsService] = 1

        # Conditionally log URL query params
        # Because of the hook points, the query arg can come in under <tt>query</tt>
        # or as a part of <tt>uri</tt> (not both).  Here we handle both cases.
        if SolarWindsAPM::Config[:httpclient][:log_args]
          if query
            kvs[:RemoteURL] = uri.to_s + '?' + SolarWindsAPM::Util.to_query(query)
          else
            kvs[:RemoteURL] = uri.to_s
          end
        else
          kvs[:RemoteURL] = uri.to_s.split('?').first
        end

        kvs[:HTTPMethod] = SolarWindsAPM::Util.upcase(method)
        kvs
      rescue => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] Error capturing httpclient KVs: #{e.message}"
        SolarWindsAPM.logger.debug e.backtrace.join('\n') if SolarWindsAPM::Config[:verbose]
      ensure
        return kvs
      end

      def do_request(method, uri, query, body, header, &block)
        # If we're not tracing, just do a fast return.
        unless SolarWindsAPM.tracing?
          add_trace_header(header)
          return super(method, uri, query, body, header, &block)
        end

        begin
          kvs = appoptics_collect(method, uri, query)

          SolarWindsAPM::API.log_entry(:httpclient, kvs)
          kvs.clear
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:httpclient][:collect_backtraces]

          add_trace_header(header)

          # The core httpclient call
          response = super(method, uri, query, body, header, &block)
          kvs[:HTTPStatus] = response.status_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response.status.to_i) && response.headers.key?('Location')
            kvs[:Location] = response.headers['Location']
          end

          response
        rescue => e
          SolarWindsAPM::API.log_exception(:httpclient, e)
          raise e
        ensure
          SolarWindsAPM::API.log_exit(:httpclient, kvs)
        end
      end

      def do_request_async(method, uri, query, body, header)
        add_trace_header(header)
        # added headers because this calls `do_get_stream` in a new thread
        # threads do not inherit thread local variables like SolarWindsAPM.trace_context
        super(method, uri, query, body, header)
      end

      def do_get_stream(req, proxy, conn)
        # called from `do_request_async` in a new thread
        # threads do not inherit thread local variables
        # therefore we use headers to continue context
        w3c_headers = get_trace_headers(req.headers)
        SolarWindsAPM.trace_context = TraceContext.new(w3c_headers)
        unless SolarWindsAPM::TraceString.sampled?(SolarWindsAPM.trace_context.tracestring)
          # trace headers already included
          return super(req, proxy, conn)
        end

        begin
          method = req.http_header.request_method

          uri = req.http_header.request_uri
          kvs = appoptics_collect(method, uri)
          kvs[:Async] = 1

          SolarWindsAPM::Context.fromString(SolarWindsAPM.trace_context.tracestring)
          SolarWindsAPM::API.log_entry(:httpclient, kvs)
          kvs.clear
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:httpclient][:collect_backtraces]

          add_trace_header(req.header)

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
          SolarWindsAPM::API.log_exception(:httpclient, e)
          raise e
        ensure
          SolarWindsAPM::API.log_exit(:httpclient, kvs)
        end
      end

      private

      def get_trace_headers(headers)
        if headers.is_a?(Array)
          traceparent = headers.find { |ele| ele.first =~ /[Tt]raceparent/ }
          tracestate = headers.find { |ele| ele.first =~ /[Tt]racestate/ }
          return { traceparent: traceparent, tracestate: tracestate }
        elsif headers.is_a?(Hash)
          return { traceparent: headers['traceparent'], tracestate: headers['tracestate'] }
        elsif headers.is_a? HTTP::Message::Headers
          return { traceparent: headers['traceparent'].first,
                   tracestate: headers['tracestate'].first }
        end
        {}
      end

      def add_trace_header(headers)
        tracestring, tracestate = w3c_context
        # Be aware of various ways to call/use httpclient
        if headers.is_a?(Array)
          headers.delete_if { |kv| kv[0] =~ /^([Tt]raceparent|[Tt]racestate)$/ }
          headers.push ['traceparent', tracestring] if tracestring
          headers.push ['tracestate', tracestate] if tracestate
        elsif headers.is_a?(Hash)
          headers['traceparent'] = tracestring if tracestring
          headers['tracestate'] = tracestate if tracestate
        elsif headers.is_a? HTTP::Message::Headers
          headers.set('traceparent', tracestring) if tracestring
          headers.set('tracestate', tracestate) if tracestate
        end
      end

      # !! this is a private method, only used in add_trace_header above
      def w3c_context
        tracestring = SolarWindsAPM::Context.toString

        unless SolarWindsAPM::TraceString.valid?(tracestring)
          return [SolarWindsAPM.trace_context&.traceparent, SolarWindsAPM.trace_context&.tracestate]
        end

        parent_id_flags = SolarWindsAPM::TraceString.span_id_flags(tracestring)
        tracestate = SolarWindsAPM::TraceState.add_sw_member(SolarWindsAPM.trace_context&.tracestate, parent_id_flags)
        [tracestring, tracestate]
      end

    end
  end
end

if SolarWindsAPM::Config[:httpclient][:enabled] && defined?(HTTPClient)
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting httpclient' if SolarWindsAPM::Config[:verbose]
  HTTPClient.prepend(SolarWindsAPM::Inst::HTTPClient)
end
