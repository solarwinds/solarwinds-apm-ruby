# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst

    # Curb instrumentation wraps instance and class methods in two classes:
    # Curl::Easy and Curl::Multi.  This CurlUtility module is used as a common module
    # to be shared among both modules.
    module CurlUtility

      ##
      # traceview_collect
      #
      # Used as a central area to retrieve and return values
      # that we're interesting in reporting to TraceView
      #
      def traceview_collect(verb = nil)
        kvs = {}

        if TraceView::Config[:curb][:cross_host]
          kvs[:IsService] = 1

          # Conditionally log query args
          if TraceView::Config[:curb][:log_args]
            kvs[:RemoteURL] = url
          else
            kvs[:RemoteURL] = url.split('?').first
          end

          kvs[:HTTPMethod] = verb if verb
        end

        # Avoid cross host tracing for blacklisted domains
        kvs[:blacklisted] = TraceView::API.blacklisted?(URI(url).hostname)
        kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:curb][:collect_backtraces]

        kvs
      rescue => e
        TraceView.logger.debug "[traceview/debug] Error capturing curb KVs: #{e.message}"
        TraceView.logger.debug e.backtrace.join('\n') if ::TraceView::Config[:verbose]
      ensure
        return kvs
      end

      ##
      # profile_curb_method
      #
      # An agnostic method that will profile any Curl::Easy method (and optional args and block)
      # that you throw at it.
      #
      def profile_curb_method(kvs, method, args, &block)
        # If we're not tracing, just do a fast return.
        return self.send(method, args, &block) if !TraceView.tracing?

        begin
          response_context = nil
          req_context = nil
          handle_cross_host = TraceView::Config[:curb][:cross_host]
          kvs.merge! traceview_collect

          TraceView::API.log_entry(:curb, kvs)
          kvs.clear

          if handle_cross_host && !kvs[:blacklisted]
            req_context = TraceView::Context.toString()
            self.headers['X-Trace'] = req_context
          end

          # The core curb call
          response = self.send(method, *args, &block)

          if handle_cross_host
            kvs[:HTTPStatus] = response_code

            # If we get a redirect, report the location header
            if ((300..308).to_a.include? response_code) && headers.key?("Location")
              kvs[:Location] = headers["Location"]
            end

            # Curb only provides a single long string of all response headers (yuck!).  So we are forced
            # to process that string to pull out the response X-Trace value.
            # Taken from https://stackoverflow.com/questions/14345805/curb-get-response-headers
            _, *response_headers = header_str.split(/[\r\n]+/).map(&:strip)
            response_headers = Hash[response_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]

            response_context = response_headers['X-Trace']
            if response_context && !kvs[:blacklisted]
              TraceView::XTrace.continue_service_context(req_context, response_context)
            end
          end

          response
        rescue => e
          TraceView::API.log_exception(:curb, e)
          raise e
        ensure
          TraceView::API.log_exit(:curb, kvs)
        end

      end
    end # CurlUtility

    # Instrumentation specific to ::Curl::Easy
    module CurlEasy
      # Common methods
      include TraceView::Inst::CurlUtility

      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :http, ::Curl::Easy)
        ::TraceView::Util.method_alias(klass, :perform, ::Curl::Easy)
        ::TraceView::Util.method_alias(klass, :http_put, ::Curl::Easy)
        ::TraceView::Util.method_alias(klass, :http_post, ::Curl::Easy)
      end

      ##
      # http_post_with_traceview
      #
      # ::Curl::Easy.new.http_post wrapper
      #
      def http_post_with_traceview(*args, &block)
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing? || TraceView.tracing_layer?(:curb)
          return http_post_without_traceview(*args)
        end

        kvs = {}
        if TraceView::Config[:curb][:cross_host]
          kvs[:HTTPMethod] = :POST
        end

        profile_curb_method(kvs, :http_post_without_traceview, args, &block)
      end

      ##
      # http_put_with_traceview
      #
      # ::Curl::Easy.new.http_put wrapper
      #
      def http_put_with_traceview(*args, &block)
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing? || TraceView.tracing_layer?(:curb)
          return http_put_without_traceview(data)
        end

        kvs = {}
        if TraceView::Config[:curb][:cross_host]
          kvs[:HTTPMethod] = :PUT
        end

        profile_curb_method(kvs, :http_post_without_traceview, args, &block)
      end

      ##
      # perform_with_traceview
      #
      # ::Curl::Easy.new.perform wrapper
      #
      def perform_with_traceview(&block)
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing? || TraceView.tracing_layer?(:curb)
          return perform_without_traceview(&block)
        end

        kvs = {}
        # This perform gets called from two places, ::Curl::Easy.new.perform
        # and Curl::Easy.new.http_head. In the case of http_head we detect the
        # HTTP verb via get info.
        if TraceView::Config[:curb][:cross_host]
          if self.getinfo(self.sym2curl(:nobody))
            kvs[:HTTPMethod] = :HEAD
          else
            kvs[:HTTPMethod] = :GET
          end
        end

        return profile_curb_method(kvs, :perform_without_traceview, nil, &block)
      end

      ##
      # http_with_traceview
      #
      # ::Curl::Easy.new.http wrapper
      #
      def http_with_traceview(verb, &block)
        # If we're not tracing, just do a fast return.
        return http_without_traceview(verb) if !TraceView.tracing?

        kvs = {}
        if TraceView::Config[:curb][:cross_host]
          kvs[:HTTPMethod] = verb
        end

        profile_curb_method(kvs, :http_without_traceview, [verb], &block)
      end
    end

    ##
    # CurlMultiCM
    #
    # This module contains the class method wrappers for the CurlMulti class.
    # This module should be _extended_ by CurlMulti.
    #
    module CurlMultiCM
      def self.extended(klass)
        ::TraceView::Util.class_method_alias(klass, :http, ::Curl::Multi)
      end

      ##
      # http_with_traceview
      #
      # ::Curl::Multi.new.http wrapper
      #
      def http_with_traceview(urls_with_config, multi_options={}, &block)
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing?
          return http_without_traceview(urls_with_config, multi_options, &block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:curb][:collect_backtraces]

          TraceView::API.log_entry(:curb_multi, kvs)

          # The core curb call
          http_without_traceview(urls_with_config, multi_options, &block)
        rescue => e
          TraceView::API.log_exception(:curb_multi, e)
          raise e
        ensure
          TraceView::API.log_exit(:curb_multi)
        end
      end
    end

    ##
    # CurlMultiIM
    #
    # This module contains the instance method wrappers for the CurlMulti class.
    # This module should be _included_ into CurlMulti.
    #
    module CurlMultiIM
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :perform, ::Curl::Multi)
      end

      ##
      # perform_with_traceview
      #
      # ::Curl::Multi.new.perform wrapper
      #
      def perform_with_traceview(&block)
        # If we're not tracing or we're not already tracing curb, just do a fast return.
        if !TraceView.tracing? || [:curb, :curb_multi].include?(TraceView.layer)
          return perform_without_traceview(&block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:curb][:collect_backtraces]

          TraceView::API.log_entry(:curb_multi, kvs)

          # The core curb call
          perform_without_traceview(&block)
        rescue => e
          TraceView::API.log_exception(:curb_multi, e)
          raise e
        ensure
          TraceView::API.log_exit(:curb_multi)
        end
      end
    end
  end
end

if TraceView::Config[:curb][:enabled] && defined?(::Curl) && RUBY_VERSION > '1.8.7'
  ::TraceView.logger.info '[traceview/loading] Instrumenting curb' if TraceView::Config[:verbose]
  ::TraceView::Util.send_include(::Curl::Easy, ::TraceView::Inst::CurlEasy)
  ::TraceView::Util.send_extend(::Curl::Multi, ::TraceView::Inst::CurlMultiCM)
  ::TraceView::Util.send_include(::Curl::Multi, ::TraceView::Inst::CurlMultiIM)
end
