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
        kvs['IsService'] = 1

        # Conditionally log query args
        if TraceView::Config[:curb][:log_args]
          kvs[:RemoteURL] = url
        else
          kvs[:RemoteURL] = url.split('?').first
        end

        kvs[:HTTPMethod] = verb if verb

        # Avoid cross host tracing for blacklisted domains
        if TraceView::API.blacklisted?(URI(url).hostname)
          kvs['Blacklisted'] = true
        end

        kvs['Backtrace'] = TraceView::API.backtrace if TraceView::Config[:curb][:collect_backtraces]
        kvs
      rescue => e
        TraceView.logger.debug "[traceview/debug] Error capturing curb KVs: #{e.message}"
        TraceView.logger.debug e.backtrace.join('\n') if ::TraceView::Config[:verbose]
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
          handle_cross_host = TraceView::Config[:curb][:cross_host]
          kvs.merge! traceview_collect

          if handle_cross_host
            # Avoid cross host tracing for blacklisted domains
            blacklisted = TraceView::API.blacklisted?(URI(url).hostname)

            req_context = TraceView::Context.toString()
            self.headers['X-Trace'] = req_context unless blacklisted
            kvs['Blacklisted'] = true if blacklisted
          end

          TraceView::API.log_entry('curb', kvs)
          kvs.clear

          # The core curb call
          response = self.send(method, *args, &block)

          kvs['HTTPStatus'] = response_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response_code) && headers.key?("Location")
            kvs["Location"] = headers["Location"]
          end

          if handle_cross_host
            response_context = headers['X-Trace']
            if response_context && !blacklisted
              TraceView::XTrace.continue_service_context(req_context, response_context)
            end
          end

          response
        rescue => e
          TraceView::API.log_exception('curb', e)
          raise e
        ensure
          TraceView::API.log_exit('curb', kvs)
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
      # ::Curl::Easy.new.perform wrapper
      #
      def http_post_with_traceview(*args, &block)
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing? || TraceView.tracing_layer?('curb')
          return http_post_without_traceview(*args)
        end

        profile_curb_method({:HTTPMethod => :POST}, :http_post_without_traceview, args, &block)
      end

      ##
      # http_put_with_traceview
      #
      # ::Curl::Easy.new.perform wrapper
      #
      def http_put_with_traceview(*args, &block)
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing? || TraceView.tracing_layer?('curb')
          return http_put_without_traceview(data)
        end

        profile_curb_method({:HTTPMethod => :PUT}, :http_post_without_traceview, args, &block)
      end

      ##
      # perform_with_traceview
      #
      # ::Curl::Easy.new.perform wrapper
      #
      def perform_with_traceview(&block)
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing? || TraceView.tracing_layer?('curb')
          return perform_without_traceview(&block)
        end

        kvs = {}
        # This perform gets called from two places, ::Curl::Easy.new.perform
        # and Curl::Easy.new.http_head. In the case of http_head we detect the
        # HTTP verb via get info.
        if self.getinfo(self.sym2curl(:nobody))
          kvs[:HTTPMethod] = :HEAD
        else
          kvs[:HTTPMethod] = :GET
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

        profile_curb_method({ :HTTPMethod => verb }, :http_without_traceview, [verb], &block)
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
          TraceView::API.log_entry('curb_multi')

          # The core curb call
          http_without_traceview(urls_with_config, multi_options, &block)
        rescue => e
          TraceView::API.log_exception('curb_multi', e)
          raise e
        ensure
          TraceView::API.log_exit('curb_multi')
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
        if !TraceView.tracing? || ['curb', 'curb_multi'].include?(TraceView.layer)
          return perform_without_traceview(&block)
        end

        begin
          kvs = {}

          TraceView::API.log_entry('curb_multi', kvs)
          kvs.clear

          # The core curb call
          perform_without_traceview(&block)
        rescue => e
          TraceView::API.log_exception('curb_multi', e)
          raise e
        ensure
          TraceView::API.log_exit('curb_multi', kvs)
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
