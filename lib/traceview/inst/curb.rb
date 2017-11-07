# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Inst

    # Curb instrumentation wraps instance and class methods in two classes:
    # Curl::Easy and Curl::Multi.  This CurlUtility module is used as a common module
    # to be shared among both modules.
    module CurlUtility

      private
      ##
      # traceview_collect
      #
      # Used as a central area to retrieve and return values
      # that we're interesting in reporting to TraceView
      #
      def traceview_collect(verb = nil)
        kvs = {}

        kvs[:IsService] = 1

        # Conditionally log query args
        if TraceView::Config[:curb][:log_args]
          kvs[:RemoteURL] = url
        else
          kvs[:RemoteURL] = url.split('?').first
        end

        kvs[:HTTPMethod] = verb if verb

        # Avoid cross host tracing for blacklisted domains
        kvs[:blacklisted] = TraceView::API.blacklisted?(URI(url).hostname)
        kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:curb][:collect_backtraces]

        kvs
      rescue => e
        TraceView.logger.debug "[traceview/debug] Error capturing curb KVs: #{e.message}"
        if TraceView::Config[:verbose]
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
          TraceView.logger.debug e.backtrace.join('\n')
        end
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
        unless TraceView.tracing?
          unless TraceView::API.blacklisted?(URI(url).hostname)
            self.headers['X-Trace'] = TraceView::Context.toString if TraceView::Context.isValid
          end
          return self.send(method, args, &block)
        end

        begin
          response_context = nil
          kvs.merge! traceview_collect

          TraceView::API.log_entry(:curb, kvs)
          kvs.clear

          # The core curb call
          unless TraceView::API.blacklisted?(URI(url).hostname)
            self.headers['X-Trace'] = TraceView::Context.toString if TraceView::Context.isValid
          end
          response = self.send(method, *args, &block)

            kvs[:HTTPStatus] = response_code

            # If we get a redirect, report the location header
            if ((300..308).to_a.include? response_code) && headers.key?("Location")
              kvs[:Location] = headers["Location"]
            end

            _, *response_headers = header_str.split(/[\r\n]+/).map(&:strip)
            response_headers = Hash[response_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]

            response_context = response_headers['X-Trace']
            if response_context && !kvs[:blacklisted]
              TraceView::XTrace.continue_service_context(self.headers['X-Trace'], response_context)
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
          unless TraceView::API.blacklisted?(URI(url).hostname)
            self.headers['X-Trace'] = TraceView::Context.toString() if TraceView::Context.isValid
          end
          return http_post_without_traceview(*args)
        end

        kvs = {}
        kvs[:HTTPMethod] = :POST

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
          unless TraceView::API.blacklisted?(URI(url).hostname)
            self.headers['X-Trace'] = TraceView::Context.toString() if TraceView::Context.isValid
          end
          return http_put_without_traceview(data)
        end

        kvs = {}
        kvs[:HTTPMethod] = :PUT

        profile_curb_method(kvs, :http_put_without_traceview, args, &block)
      end

      ##
      # perform_with_traceview
      #
      # ::Curl::Easy.new.perform wrapper
      #
      def perform_with_traceview(&block)
        # If we're not tracing, just do a fast return.
        # excluding curb layer: because the curb C code for easy.http calls perform,
        # we have to make sure we don't log again
        if !TraceView.tracing? || TraceView.tracing_layer?(:curb)
          unless TraceView::API.blacklisted?(URI(url).hostname)
            self.headers['X-Trace'] = TraceView::Context.toString() if TraceView::Context.isValid
          end
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

        profile_curb_method(kvs, :perform_without_traceview, nil, &block)
      end

      ##
      # http_with_traceview
      #
      # ::Curl::Easy.new.http wrapper
      #
      def http_with_traceview(verb, &block)
        # If we're not tracing, just do a fast return.
        unless TraceView.tracing?
          unless TraceView::API.blacklisted?(URI(url).hostname)
            self.headers['X-Trace'] = TraceView::Context.toString() if TraceView::Context.isValid
          end
          return http_without_traceview(verb)
        end

        kvs = {}
        kvs[:HTTPMethod] = verb

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
      include TraceView::Inst::CurlUtility

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
        unless TraceView.tracing?
          urls_with_config.each do |conf|
            unless TraceView::API.blacklisted?(URI(conf[:url]).hostname)
              conf[:headers] ||= {}
              conf[:headers]['X-Trace'] = TraceView::Context.toString if TraceView::Context.isValid
            end
          end
          return http_without_traceview(urls_with_config, multi_options, &block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:curb][:collect_backtraces]

          TraceView::API.log_entry(:curb_multi, kvs)
          context = TraceView::Context.toString
          urls_with_config.each do |conf|
            unless TraceView::API.blacklisted?(URI(conf[:url]).hostname)
              conf[:headers] ||= {}
              conf[:headers]['X-Trace'] = context if TraceView::Context.isValid
            end
          end

          traces = []
          # The core curb call
          http_without_traceview(urls_with_config, multi_options) do |easy, response_code, method|
            # this is the only way we can access the headers, they are not exposed otherwise
            unless TraceView::API.blacklisted?(URI(easy.url).hostname)
              xtrace = easy.header_str.scan(/X-Trace: ([0-9A-F]*)/).map{ |m| m[0] }
              traces << xtrace[0] unless xtrace.empty?
            end
            block.call(easy, response_code, method) if block
          end
          TraceView::XTrace.continue_service_context(context, traces.pop) unless traces.empty?
        rescue => e
          TraceView::API.log_exception(:curb_multi, e)
          raise e
        ensure
          TraceView::API.log_multi_exit(:curb_multi, traces)
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
      include TraceView::Inst::CurlUtility

      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :perform, ::Curl::Multi)
      end

      ##
      # perform_with_traceview
      #
      # ::Curl::Multi.new.perform wrapper
      #
      # the reason we instrument this method is because it can be called directly,
      # therefore we exclude calls that already have a curb layer assigned
      # Be aware: this method is also called from the c-implementation
      #
      def perform_with_traceview(&block)
        # If we're not tracing or we're already tracing curb, just do a fast return.
        if !TraceView.tracing? || [:curb, :curb_multi].include?(TraceView.layer)
          self.requests.each do |request|
            unless TraceView::API.blacklisted?(URI(request.url).hostname)
              request.headers['X-Trace'] = TraceView::Context.toString if TraceView::Context.isValid
            end
          end
          return perform_without_traceview(&block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:curb][:collect_backtraces]

          TraceView::API.log_entry(:curb_multi, kvs)

          self.requests.each do |request|
            unless TraceView::API.blacklisted?(URI(request.url).hostname)
              request.headers['X-Trace'] = TraceView::Context.toString if TraceView::Context.isValid
            end
          end

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
