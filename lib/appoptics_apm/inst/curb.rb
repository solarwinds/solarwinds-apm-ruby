# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst

    # Curb instrumentation wraps instance and class methods in two classes:
    # Curl::Easy and Curl::Multi.  This CurlUtility module is used as a common module
    # to be shared among both modules.
    module CurlUtility

      private
      ##
      # appoptics_collect
      #
      # Used as a central area to retrieve and return values
      # that we're interesting in reporting to AppOpticsAPM
      #
      def appoptics_collect(verb = nil)
        kvs = {}

        kvs[:Spec] = 'rsc'
        kvs[:IsService] = 1

        # Conditionally log query args
        if AppOpticsAPM::Config[:curb][:log_args]
          kvs[:RemoteURL] = url
        else
          kvs[:RemoteURL] = url.split('?').first
        end

        kvs[:HTTPMethod] = verb if verb

        # Avoid cross host tracing for blacklisted domains
        kvs[:blacklisted] = AppOpticsAPM::API.blacklisted?(URI(url).hostname)

        kvs
      rescue => e
        AppOpticsAPM.logger.debug "[appoptics_apm/debug] Error capturing curb KVs: #{e.message}"
        if AppOpticsAPM::Config[:verbose]
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
          AppOpticsAPM.logger.debug e.backtrace.join('\n')
        end
      ensure
        return kvs
      end
      
      ##
      # trace_curb_method
      #
      # An agnostic method that will profile any Curl::Easy method (and optional args and block)
      # that you throw at it.
      #
      def trace_curb_method(kvs, method, args, &block)
        # If we're not tracing, just do a fast return.
        unless AppOpticsAPM.tracing?
          unless AppOpticsAPM::API.blacklisted?(URI(url).hostname)
            self.headers['traceparent'] = AppOpticsAPM::Context.toString if AppOpticsAPM::Context.isValid
          end
          return self.send(method, args, &block)
        end

        begin
          response_context = nil
          kvs.merge! appoptics_collect

          AppOpticsAPM::API.log_entry(:curb, kvs)
          kvs.clear

          # The core curb call
          unless AppOpticsAPM::API.blacklisted?(URI(url).hostname)
            self.headers['traceparent'] = AppOpticsAPM::Context.toString if AppOpticsAPM::Context.isValid
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
              AppOpticsAPM::XTrace.continue_service_context(self.headers['traceparent'], response_context)
            end

          response
        rescue => e
          AppOpticsAPM::API.log_exception(:curb, e)
          raise e
        ensure
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:curb][:collect_backtraces]
          AppOpticsAPM::API.log_exit(:curb, kvs)
        end
      end
      
    end # CurlUtility

    # Instrumentation specific to ::Curl::Easy
    module CurlEasy
      # Common methods
      include AppOpticsAPM::Inst::CurlUtility

      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :http, ::Curl::Easy)
        AppOpticsAPM::Util.method_alias(klass, :perform, ::Curl::Easy)
        AppOpticsAPM::Util.method_alias(klass, :http_put, ::Curl::Easy)
        AppOpticsAPM::Util.method_alias(klass, :http_post, ::Curl::Easy)
      end

      ##
      # http_post_with_appoptics
      #
      # ::Curl::Easy.new.http_post wrapper
      #
      def http_post_with_appoptics(*args, &block)
        # If we're not tracing, just do a fast return.
        if !AppOpticsAPM.tracing? || AppOpticsAPM.tracing_layer?(:curb)
          unless AppOpticsAPM::API.blacklisted?(URI(url).hostname)
            self.headers['traceparent'] = AppOpticsAPM::Context.toString() if AppOpticsAPM::Context.isValid
          end
          return http_post_without_appoptics(*args)
        end

        kvs = {}
        kvs[:HTTPMethod] = :POST

        trace_curb_method(kvs, :http_post_without_appoptics, args, &block)
      end

      ##
      # http_put_with_appoptics
      #
      # ::Curl::Easy.new.http_put wrapper
      #
      def http_put_with_appoptics(*args, &block)
        # If we're not tracing, just do a fast return.
        if !AppOpticsAPM.tracing? || AppOpticsAPM.tracing_layer?(:curb)
          unless AppOpticsAPM::API.blacklisted?(URI(url).hostname)
            self.headers['traceparent'] = AppOpticsAPM::Context.toString() if AppOpticsAPM::Context.isValid
          end
          return http_put_without_appoptics(data)
        end

        kvs = {}
        kvs[:HTTPMethod] = :PUT

        trace_curb_method(kvs, :http_put_without_appoptics, args, &block)
      end

      ##
      # perform_with_appoptics
      #
      # ::Curl::Easy.new.perform wrapper
      #
      def perform_with_appoptics(&block)
        # If we're not tracing, just do a fast return.
        # excluding curb layer: because the curb C code for easy.http calls perform,
        # we have to make sure we don't log again
        if !AppOpticsAPM.tracing? || AppOpticsAPM.tracing_layer?(:curb)
          unless AppOpticsAPM::API.blacklisted?(URI(url).hostname)
            self.headers['traceparent'] = AppOpticsAPM::Context.toString() if AppOpticsAPM::Context.isValid
          end
          return perform_without_appoptics(&block)
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

        trace_curb_method(kvs, :perform_without_appoptics, nil, &block)
      end

      ##
      # http_with_appoptics
      #
      # ::Curl::Easy.new.http wrapper
      #
      def http_with_appoptics(verb, &block)
        # If we're not tracing, just do a fast return.
        unless AppOpticsAPM.tracing?
          unless AppOpticsAPM::API.blacklisted?(URI(url).hostname)
            self.headers['traceparent'] = AppOpticsAPM::Context.toString() if AppOpticsAPM::Context.isValid
          end
          return http_without_appoptics(verb)
        end

        kvs = {}
        kvs[:HTTPMethod] = verb

        trace_curb_method(kvs, :http_without_appoptics, [verb], &block)
      end
    end

    ##
    # CurlMultiCM
    #
    # This module contains the class method wrappers for the CurlMulti class.
    # This module should be _extended_ by CurlMulti.
    #
    module CurlMultiCM
      include AppOpticsAPM::Inst::CurlUtility

      def self.extended(klass)
        AppOpticsAPM::Util.class_method_alias(klass, :http, ::Curl::Multi)
      end

      ##
      # http_with_appoptics
      #
      # ::Curl::Multi.new.http wrapper
      #
      def http_with_appoptics(urls_with_config, multi_options={}, &block)
        # If we're not tracing, just do a fast return.
        unless AppOpticsAPM.tracing?
          urls_with_config.each do |conf|
            unless AppOpticsAPM::API.blacklisted?(URI(conf[:url]).hostname)
              conf[:headers] ||= {}
              conf[:headers]['traceparent'] = AppOpticsAPM::Context.toString if AppOpticsAPM::Context.isValid
            end
          end
          return http_without_appoptics(urls_with_config, multi_options, &block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:curb][:collect_backtraces]

          AppOpticsAPM::API.log_entry(:curb_multi, kvs)
          context = AppOpticsAPM::Context.toString
          urls_with_config.each do |conf|
            unless AppOpticsAPM::API.blacklisted?(URI(conf[:url]).hostname)
              conf[:headers] ||= {}
              conf[:headers]['traceparent'] = context if AppOpticsAPM::Context.isValid
            end
          end

          traces = []
          # The core curb call
          http_without_appoptics(urls_with_config, multi_options) do |easy, response_code, method|
            # this is the only way we can access the headers, they are not exposed otherwise
            unless AppOpticsAPM::API.blacklisted?(URI(easy.url).hostname)
              xtrace = easy.header_str.scan(/traceparent: ([0-9A-F]*)/).map{ |m| m[0] }
              traces << xtrace[0] unless xtrace.empty?
            end
            block.call(easy, response_code, method) if block
          end
          AppOpticsAPM::XTrace.continue_service_context(context, traces.pop) unless traces.empty?
        rescue => e
          AppOpticsAPM::API.log_exception(:curb_multi, e)
          raise e
        ensure
          AppOpticsAPM::API.log_multi_exit(:curb_multi, traces)
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
      include AppOpticsAPM::Inst::CurlUtility

      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :perform, ::Curl::Multi)
      end

      ##
      # perform_with_appoptics
      #
      # ::Curl::Multi.new.perform wrapper
      #
      # the reason we instrument this method is because it can be called directly,
      # therefore we exclude calls that already have a curb layer assigned
      # Be aware: this method is also called from the c-implementation
      #
      def perform_with_appoptics(&block)
        # If we're not tracing or we're already tracing curb, just do a fast return.
        if !AppOpticsAPM.tracing? || [:curb, :curb_multi].include?(AppOpticsAPM.layer)
          self.requests.each do |request|
            request = request[1] if request.is_a?(Array)
            unless AppOpticsAPM::API.blacklisted?(URI(request.url).hostname)
              request.headers['traceparent'] = AppOpticsAPM::Context.toString if AppOpticsAPM::Context.isValid
            end
          end
          return perform_without_appoptics(&block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:curb][:collect_backtraces]

          AppOpticsAPM::API.log_entry(:curb_multi, kvs)

          self.requests.each do |request|
            request = request[1] if request.is_a?(Array)
            unless AppOpticsAPM::API.blacklisted?(URI(request.url).hostname)
              request.headers['traceparent'] = AppOpticsAPM::Context.toString if AppOpticsAPM::Context.isValid
            end
          end

          perform_without_appoptics(&block)
        rescue => e
          AppOpticsAPM::API.log_exception(:curb_multi, e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit(:curb_multi)
        end
      end
    end
  end
end

if AppOpticsAPM::Config[:curb][:enabled] && defined?(::Curl)
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting curb' if AppOpticsAPM::Config[:verbose]
  AppOpticsAPM::Util.send_include(::Curl::Easy, AppOpticsAPM::Inst::CurlEasy)
  AppOpticsAPM::Util.send_extend(::Curl::Multi, AppOpticsAPM::Inst::CurlMultiCM)
  AppOpticsAPM::Util.send_include(::Curl::Multi, AppOpticsAPM::Inst::CurlMultiIM)
end
