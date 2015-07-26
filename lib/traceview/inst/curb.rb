# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst

    # Curb instrumentation wraps instance and class methods in three classes: Curl,
    # Curl::Easy and Curl::Multi.  This CurlUtility module is used as a common module
    # to be shared among all three Curl modules
    module CurlUtility

      ##
      # traceview_collect
      #
      # Used as a central area to retrieve and return values
      # that we're interesting in reporting to TraceView
      #
      def traceview_collect(url, verb = nil)
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
      # An agnostic method that will profile any method (and optional args and block)
      # that you throw at it.
      #
      def profile_curb_method(kvs, method, args, &block)
        # If we're not tracing, just do a fast return.
        return self.send(method, args, &block) if !TraceView.tracing?

        begin
          handle_cross_host = TraceView::Config[:curb][:cross_host]

          if handle_cross_host
            # We're getting call here from Curl class methods, Curl::Easy class _and_
            # instance methods and then there is also Curl::Multi.  Try to handle all
            # as elegantly as possibile.
            if self == ::Curl
              handle = Thread.current[:curb_curl] ||= Curl::Easy.new
            else
              handle = self
            end
            req_context = TraceView::Context.toString()
            handle.headers['X-Trace'] = req_context unless kvs[:Blacklisted]
            Thread.current[:curb_curl] = handle if handle.is_a?(::Curl::Easy)
          end

          TraceView::API.log_entry('curb', kvs)

          # The core call
          response = self.send(method, *args, &block)

          if [TrueClass, FalseClass].include?(response.class)
            easy = self
          else
            easy = response
          end

          kvs = { :HTTPStatus => easy.response_code }

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? kvs[:HTTPStatus]) && easy.headers.key?("Location")
            kvs[:Location] = easy.headers["Location"]
          end

          if handle_cross_host && easy.headers['X-Trace'] && !kvs[:Blacklisted]
            TraceView::XTrace.continue_service_context(req_context, easy.headers['X-Trace'])
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
      end

      ##
      # perform_with_traceview
      #
      # ::Curl::Easy.new.perform wrapper
      #
      def perform_with_traceview
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing? || TraceView.tracing_layer?('curb')
          return perform_without_traceview
        end

        begin
          response_context = nil
          handle_cross_host = TraceView::Config[:curb][:cross_host]
          kvs = traceview_collect(url)

          # This perform gets called from two places, ::Curl::Easy.new.perform
          # and Curl::Easy.new.http_head. In the case of http_head we detect the
          # HTTP verb via get info.
          if self.getinfo(self.sym2curl(:nobody))
            kvs[:HTTPMethod] = :HEAD
          else
            kvs[:HTTPMethod] = :GET
          end

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
          response = perform_without_traceview

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

      ##
      # http_with_traceview
      #
      # ::Curl::Easy.new.http wrapper
      #
      def http_with_traceview(verb)
        # If we're not tracing, just do a fast return.
        return http_without_traceview(verb) if !TraceView.tracing?

        begin
          response_context = nil
          handle_cross_host = TraceView::Config[:curb][:cross_host]
          kvs = traceview_collect(url, verb)

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
          response = http_without_traceview(verb)

          if response
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
          else
            # The call returned false; error
            require 'byebug'; debugger
          end

          response
        rescue => e
          TraceView::API.log_exception('curb', e)
          raise e
        ensure
          TraceView::API.log_exit('curb', kvs)
        end
      end
    end

    module CurlMulti
      # Common methods
      include TraceView::Inst::CurlUtility

      def self.extended(klass)
        ::TraceView::Util.class_method_alias(klass, :http, ::Curl::Multi)
      end

      ##
      # http_with_traceview
      #
      # ::Curl::Multi.new.http wrapper
      #
      def http_with_traceview(urls_with_config, multi_options={}, &blk)
        # If we're not tracing, just do a fast return.
        if !TraceView.tracing?
          return http_without_traceview(urls_with_config, multi_options={}, &blk)
        end

        begin
          kvs = {}

          TraceView::API.log_entry('curb_multi', kvs)
          kvs.clear

          # The core curb call
          http_without_traceview(urls_with_config, multi_options, &blk)
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

if TraceView::Config[:curb][:enabled] && defined?(::Curl)
  ::TraceView.logger.info '[traceview/loading] Instrumenting curb' if TraceView::Config[:verbose]
  ::TraceView::Util.send_include(::Curl::Easy, ::TraceView::Inst::CurlEasy)
  ::TraceView::Util.send_extend(::Curl::Multi, ::TraceView::Inst::CurlMulti)
end
