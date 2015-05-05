# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module HTTPClient
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :do_request, ::HTTPClient)
        ::Oboe::Util.method_alias(klass, :do_request_async, ::HTTPClient)
        ::Oboe::Util.method_alias(klass, :do_get_stream, ::HTTPClient)
      end

      def oboe_collect(method, uri, query)
        kvs = {}
        kvs['IsService'] = 1
        kvs['RemoteProtocol'] = ::Oboe::Util.upcase(uri.scheme)
        kvs['RemoteHost'] = uri.hostname
        kvs['ServiceArg'] = uri.request_uri
        kvs['HTTPMethod'] = ::Oboe::Util.upcase(method)
        kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:httpclient][:collect_backtraces]
        kvs
      rescue => e
        Oboe.logger.debug "[oboe/debug] Error capturing httpclient KVs: #{e.message}"
        Oboe.logger.debug e.backtrace.join('\n') if ::Oboe::Config[:verbose]
      end

      def do_request_with_oboe(method, uri, query, body, header, &block)
        # If we're not tracing, just do a fast return.
        if !Oboe.tracing?
          return request_without_oboe(method, uri, query, body, header, &block)
        end

        begin
          response_context = nil

          # Avoid cross host tracing for blacklisted domains
          blacklisted = Oboe::API.blacklisted?(uri.hostname)

          kvs = oboe_collect(method, uri, query)
          kvs['Blacklisted'] = true if blacklisted

          Oboe::API.log_entry('httpclient', kvs)
          kvs.clear

          req_context = Oboe::Context.toString()

          # Be aware of various ways to call/use httpclient
          if header.is_a?(Array)
            header.push ["X-Trace", req_context]
          elsif header.is_a?(Hash)
            header['X-Trace'] = req_context unless blacklisted
          end

          # The core httpclient call
          response = do_request_without_oboe(method, uri, query, body, header, &block)

          response_context = response.headers['X-Trace']
          kvs['HTTPStatus'] = response.status_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response.status.to_i) && response.headers.key?("Location")
            kvs["Location"] = response.headers["Location"]
          end

          if response_context && !blacklisted
            Oboe::XTrace.continue_service_context(req_context, response_context)
          end

          response
        rescue => e
          Oboe::API.log_exception('httpclient', e)
          raise e
        ensure
          Oboe::API.log_exit('httpclient', kvs)
        end
      end

      def do_request_async_with_oboe(method, uri, query, body, header)
        if Oboe.tracing?
          # Since async is done by calling Thread.new { .. }, we somehow
          # have to pass the tracing context into that new thread.  Here
          # we stowaway the context in the request headers to be picked up
          # (and removed from req headers) in do_get_stream.
          if header.is_a?(Array)
            header.push ["oboe.context", Oboe::Context.toString]
          elsif header.is_a?(Hash)
            header['oboe.context'] = Oboe::Context.toString
          end
        end

        do_request_async_without_oboe(method, uri, query, body, header)
      end

      def do_get_stream_with_oboe(req, proxy, conn)
        unless req.headers.key?("oboe.context")
          return do_get_stream_without_oboe(req, proxy, conn)
        end

        # Pickup context and delete the headers stowaway
        Oboe::Context.fromString req.headers["oboe.context"]
        req.header.delete "oboe.context"

        begin
          response_context = nil
          uri = req.http_header.request_uri
          method = req.http_header.request_method
          query = req.http_header.request_uri.query

          # Avoid cross host tracing for blacklisted domains
          blacklisted = Oboe::API.blacklisted?(uri.hostname)

          kvs = oboe_collect(method, uri, query)
          kvs['Blacklisted'] = true if blacklisted
          kvs['Async'] = 1

          Oboe::API.log_entry('httpclient', kvs)
          kvs.clear

          req_context = Oboe::Context.toString()
          req.header.add('X-Trace', req_context)

          # The core httpclient call
          response = do_get_stream_without_oboe(req, proxy, conn)

          response_context = response.headers['X-Trace']
          kvs['HTTPStatus'] = response.status_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response.status.to_i) && response.headers.key?("Location")
            kvs["Location"] = response.headers["Location"]
          end

          if response_context && !blacklisted
            Oboe::XTrace.continue_service_context(req_context, response_context)
          end

          response
        rescue => e
          Oboe::API.log_exception('httpclient', e)
          raise e
        ensure
          # Oboe::API.log_exit('httpclient', kvs.merge('Async' => 1))
          Oboe::API.log_exit('httpclient', kvs)
        end
      end
    end
  end
end

if Oboe::Config[:httpclient][:enabled] && defined?(::HTTPClient)
  ::Oboe.logger.info '[oboe/loading] Instrumenting httpclient' if Oboe::Config[:verbose]
  ::Oboe::Util.send_include(::HTTPClient, ::Oboe::Inst::HTTPClient)
end
