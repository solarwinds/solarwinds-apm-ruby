# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst

    # Curb instrumentation wraps instance and class methods in two classes:
    # Curl::Easy and Curl::Multi.  This CurlUtility module is used as a common module
    # to be shared among both modules.
    module CurlUtility
      include SolarWindsAPM::SDK::TraceContextHeaders

      private
      ##
      # appoptics_collect
      #
      # Used as a central area to retrieve and return values
      # that we're interesting in reporting to SolarWindsAPM
      #
      def appoptics_collect(verb = nil)
        kvs = {}

        kvs[:Spec] = 'rsc'
        kvs[:IsService] = 1

        # Conditionally log query args
        if SolarWindsAPM::Config[:curb][:log_args]
          kvs[:RemoteURL] = url
        else
          kvs[:RemoteURL] = url.split('?').first
        end

        kvs[:HTTPMethod] = verb if verb

        kvs
      rescue => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] Error capturing curb KVs: #{e.message}"
        if SolarWindsAPM::Config[:verbose]
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
          SolarWindsAPM.logger.debug e.backtrace.join('\n')
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
        unless SolarWindsAPM.tracing?
          add_tracecontext_headers(self.headers)
          return self.send(method, args, &block)
        end

        begin
          kvs.merge! appoptics_collect

          SolarWindsAPM::API.log_entry(:curb, kvs)
          kvs.clear

          # The core curb call
          add_tracecontext_headers(self.headers)
          response = self.send(method, *args, &block)

          kvs[:HTTPStatus] = response_code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? response_code) && headers.key?("Location")
            kvs[:Location] = headers["Location"]
          end

          response
        rescue => e
          SolarWindsAPM::API.log_exception(:curb, e)
          raise e
        ensure
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:curb][:collect_backtraces]
          SolarWindsAPM::API.log_exit(:curb, kvs)
        end
      end
      
    end # CurlUtility

    # Instrumentation specific to ::Curl::Easy
    module CurlEasy
      # Common methods
      include SolarWindsAPM::Inst::CurlUtility

      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :http, ::Curl::Easy)
        SolarWindsAPM::Util.method_alias(klass, :perform, ::Curl::Easy)
        SolarWindsAPM::Util.method_alias(klass, :http_put, ::Curl::Easy)
        SolarWindsAPM::Util.method_alias(klass, :http_post, ::Curl::Easy)
      end

      ##
      # http_post_with_appoptics
      #
      # ::Curl::Easy.new.http_post wrapper
      #
      def http_post_with_appoptics(*args, &block)
        # If we're not tracing, just do a fast return.
        if !SolarWindsAPM.tracing? || SolarWindsAPM.tracing_layer?(:curb)
          add_tracecontext_headers(self.headers)
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
        if !SolarWindsAPM.tracing? || SolarWindsAPM.tracing_layer?(:curb)
          add_tracecontext_headers(self.headers)
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
        if !SolarWindsAPM.tracing? || SolarWindsAPM.tracing_layer?(:curb)
          add_tracecontext_headers(self.headers)
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
        unless SolarWindsAPM.tracing?
          add_tracecontext_headers(self.headers)
          # If we're not tracing, just do a fast return.
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
      include SolarWindsAPM::Inst::CurlUtility

      def self.extended(klass)
        SolarWindsAPM::Util.class_method_alias(klass, :http, ::Curl::Multi)
      end

      ##
      # http_with_appoptics
      #
      # ::Curl::Multi.new.http wrapper
      #
      def http_with_appoptics(urls_with_config, multi_options={}, &block)
        # If we're not tracing, just do a fast return.
        unless SolarWindsAPM.tracing?
          urls_with_config.each do |conf|
            conf[:headers] ||= {}
            add_tracecontext_headers(conf[:headers])
          end
          return http_without_appoptics(urls_with_config, multi_options, &block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:curb][:collect_backtraces]

          SolarWindsAPM::API.log_entry(:curb_multi, kvs)
          context = SolarWindsAPM::Context.toString

          traces = []
          urls_with_config.each do |conf|
            conf[:headers] ||= {}
            add_tracecontext_headers(conf[:headers])
          end
          # The core curb call
          http_without_appoptics(urls_with_config, multi_options)
        rescue => e
          SolarWindsAPM::API.log_exception(:curb_multi, e)
          raise e
        ensure
          SolarWindsAPM::API.log_exit(:curb_multi)
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
      include SolarWindsAPM::Inst::CurlUtility

      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :perform, ::Curl::Multi)
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
        self.requests.each do |request|
          request = request[1] if request.is_a?(Array)
          add_tracecontext_headers(request.headers)
        end
        # If we're not tracing or we're already tracing curb, just do a fast return.
        if !SolarWindsAPM.tracing? || [:curb, :curb_multi].include?(SolarWindsAPM.layer)
          return perform_without_appoptics(&block)
        end

        begin
          kvs = {}
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:curb][:collect_backtraces]

          SolarWindsAPM::API.log_entry(:curb_multi, kvs)

          perform_without_appoptics(&block)
        rescue => e
          SolarWindsAPM::API.log_exception(:curb_multi, e)
          raise e
        ensure
          SolarWindsAPM::API.log_exit(:curb_multi)
        end
      end
    end
  end
end

if SolarWindsAPM::Config[:curb][:enabled] && defined?(::Curl)
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting curb' if SolarWindsAPM::Config[:verbose]
  SolarWindsAPM::Util.send_include(::Curl::Easy, SolarWindsAPM::Inst::CurlEasy)
  SolarWindsAPM::Util.send_extend(::Curl::Multi, SolarWindsAPM::Inst::CurlMultiCM)
  SolarWindsAPM::Util.send_include(::Curl::Multi, SolarWindsAPM::Inst::CurlMultiIM)
end
