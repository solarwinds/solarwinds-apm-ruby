# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module HTTPClient
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :do_request, ::HTTPClient)
        ::AppOpticsAPM::Util.method_alias(klass, :do_request_async, ::HTTPClient)
        ::AppOpticsAPM::Util.method_alias(klass, :do_get_stream, ::HTTPClient)
      end

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

        kvs[:HTTPMethod] = ::AppOpticsAPM::Util.upcase(method)
        kvs
      rescue => e
        AppOpticsAPM.logger.debug "[appoptics_apm/debug] Error capturing httpclient KVs: #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace.join('\n') if ::AppOpticsAPM::Config[:verbose]
      ensure
        return kvs
      end

      def do_request_with_appoptics(method, uri, query, body, header, &block)
        # Avoid cross host tracing for blacklisted domains
        blacklisted = AppOpticsAPM::API.blacklisted?(uri.hostname)

        # If we're not tracing, just do a fast return.
        unless AppOpticsAPM.tracing?
          add_xtrace_header(header) unless blacklisted
          return do_request_without_appoptics(method, uri, query, body, header, &block)
        end

        begin
          req_context = nil
          response_context = nil

          kvs = appoptics_collect(method, uri, query)
          kvs[:Blacklisted] = true if blacklisted

          AppOpticsAPM::API.log_entry(:httpclient, kvs)
          kvs.clear
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:httpclient][:collect_backtraces]

          req_context = add_xtrace_header(header) unless blacklisted

          # The core httpclient call
          response = do_request_without_appoptics(method, uri, query, body, header, &block)

          response_context = response.headers['X-Trace']
          kvs[:HTTPStatus] = response.status_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response.status.to_i) && response.headers.key?('Location')
            kvs[:Location] = response.headers['Location']
          end

          if response_context && !blacklisted
            AppOpticsAPM::XTrace.continue_service_context(req_context, response_context)
          end

          response
        rescue => e
          AppOpticsAPM::API.log_exception(:httpclient, e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit(:httpclient, kvs)
        end
      end

      def do_request_async_with_appoptics(method, uri, query, body, header)
        add_xtrace_header(header)
        do_request_async_without_appoptics(method, uri, query, body, header)
      end

      def do_get_stream_with_appoptics(req, proxy, conn)
        AppOpticsAPM::Context.fromString(req.header['X-Trace'].first) unless req.header['X-Trace'].empty?
        # Avoid cross host tracing for blacklisted domains
        uri = req.http_header.request_uri
        blacklisted = AppOpticsAPM::API.blacklisted?(uri.hostname)

        unless AppOpticsAPM.tracing?
          req.header.delete('X-Trace') if blacklisted
          return do_get_stream_without_appoptics(req, proxy, conn)
        end

        begin
          response = nil
          req_context = nil
          method = req.http_header.request_method

          kvs = appoptics_collect(method, uri)
          kvs[:Blacklisted] = true if blacklisted
          kvs[:Async] = 1

          AppOpticsAPM::API.log_entry(:httpclient, kvs)
          kvs.clear
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:httpclient][:collect_backtraces]

          blacklisted ? req.header.delete('X-Trace') : req_context = add_xtrace_header(req.header)

          # The core httpclient call
          result = do_get_stream_without_appoptics(req, proxy, conn)

          # Older HTTPClient < 2.6.0 returns HTTPClient::Connection
          if result.is_a?(::HTTP::Message)
            response = result
          else
            response = conn.pop
          end

          response_context = response.headers['X-Trace']
          kvs[:HTTPStatus] = response.status_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response.status.to_i) && response.headers.key?('Location')
            kvs[:Location] = response.headers['Location']
          end

          if response_context && !blacklisted
            AppOpticsAPM::XTrace.continue_service_context(req_context, response_context)
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

      def add_xtrace_header(headers)
        req_context = AppOpticsAPM::Context.toString
        return nil unless AppOpticsAPM::XTrace.valid?(req_context)
        # Be aware of various ways to call/use httpclient
        if headers.is_a?(Array)
          headers.delete_if { |kv| kv[0] == 'X-Trace' }
          headers.push ['X-Trace', req_context]
        elsif headers.is_a?(Hash)
          headers['X-Trace'] = req_context
        elsif headers.is_a? HTTP::Message::Headers
          headers.set('X-Trace', req_context)
        end
        req_context
      end
    end
  end
end

if AppOpticsAPM::Config[:httpclient][:enabled] && defined?(::HTTPClient)
  ::AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting httpclient' if AppOpticsAPM::Config[:verbose]
  ::AppOpticsAPM::Util.send_include(::HTTPClient, ::AppOpticsAPM::Inst::HTTPClient)
end
