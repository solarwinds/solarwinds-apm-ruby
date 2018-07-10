#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module API
    ##
    # Module to create profiling traces for blocks of code or methods
    module Profiling
      ##
      # Public: Profile a given block of code. Detect any exceptions thrown by
      # the block and report errors.
      #
      # ==== Arguments
      #
      # * +profile_name+ - A name used to identify the block being profiled.
      # * +report_kvs+ - A hash containing key/value pairs that will be reported along
      #   with the event of this profile (optional).
      # * +with_backtrace+ - Boolean to indicate whether a backtrace should
      #   be collected with this trace event.
      #
      # ==== Example
      #
      #   def computation(n)
      #     AppOpticsAPM::API.profile('fib', { :n => n }) do
      #       fib(n)
      #     end
      #   end
      #
      # Returns the result of the block.
      #

      def profile(profile_name, report_kvs = {}, with_backtrace = false)
        return yield unless AppOpticsAPM.tracing?

        begin
          report_kvs[:Language] ||= :ruby
          report_kvs[:ProfileName] ||= profile_name
          report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if with_backtrace

          AppOpticsAPM::API.log(nil, :profile_entry, report_kvs)

          begin
            yield
          rescue => e
            log_exception(nil, e)
            raise
          ensure
            exit_kvs = {}
            exit_kvs[:Language] = :ruby
            exit_kvs[:ProfileName] = report_kvs[:ProfileName]

            AppOpticsAPM::API.log(nil, :profile_exit, exit_kvs)
          end
        end
      end

      ##
      # Public: Add profiling to a method on a class or module.  That method can be of any (accessible)
      # type (instance, singleton, private, protected etc.).
      #
      # ==== Arguments
      #
      # * +klass+  - the class or module that has the method to profile
      # * +method+ - the method to profile.  Can be singleton, instance, private etc...
      # * +opts+   - a hash specifying the one or more of the following options:
      #   * +:arguments+  - report the arguments passed to <tt>method</tt> on each profile (default: false)
      #   * +:result+     - report the return value of <tt>method</tt> on each profile (default: false)
      #   * +:backtrace+  - report the return value of <tt>method</tt> on each profile (default: false)
      #   * +:name+       - alternate name for the profile reported in the dashboard (default: method name)
      # * +extra_kvs+ - a hash containing any additional key/value pairs you would like reported with the profile
      #
      # ==== Example
      #
      #   opts = {}
      #   opts[:backtrace] = true
      #   opts[:arguments] = false
      #   opts[:name] = :array_sort
      #
      #   AppOpticsAPM::API.profile_method(Array, :sort, opts)
      #
      def profile_method(klass, method, opts = {}, extra_kvs = {})
        # If we're on an unsupported platform (ahem Mac), just act
        # like we did something to nicely play the no-op part.
        return true unless AppOpticsAPM.loaded

        if !klass.is_a?(Module)
          AppOpticsAPM.logger.warn "[appoptics_apm/error] profile_method: Not sure what to do with #{klass}.  Send a class or module."
          return false

        elsif !method.is_a?(Symbol)
          if method.is_a?(String)
            method = method.to_sym
          else
            AppOpticsAPM.logger.warn "[appoptics_apm/error] profile_method: Not sure what to do with #{method}.  Send a string or symbol for method."
            return false
          end
        end

        instance_method = klass.instance_methods.include?(method) || klass.private_instance_methods.include?(method)
        class_method = klass.singleton_methods.include?(method)

        # Make sure the request klass::method exists
        if !instance_method && !class_method
          AppOpticsAPM.logger.warn "[appoptics_apm/error] profile_method: Can't instrument #{klass}.#{method} as it doesn't seem to exist."
          AppOpticsAPM.logger.warn "[appoptics_apm/error] #{__FILE__}:#{__LINE__}"
          return false
        end

        # Strip '!' or '?' from method if present
        safe_method_name = method.to_s.chop if method.to_s =~ /\?$|\!$/
        safe_method_name ||= method

        without_appoptics = "#{safe_method_name}_without_appoptics"
        with_appoptics    = "#{safe_method_name}_with_appoptics"

        # Check if already profiled
        if klass.instance_methods.include?(with_appoptics.to_sym) ||
           klass.singleton_methods.include?(with_appoptics.to_sym)
          AppOpticsAPM.logger.warn "[appoptics_apm/error] profile_method: #{klass}::#{method} already profiled."
          AppOpticsAPM.logger.warn "[appoptics_apm/error] profile_method: #{__FILE__}:#{__LINE__}"
          return false
        end

        source_location = []
        if instance_method
          ::AppOpticsAPM::Util.send_include(klass, ::AppOpticsAPM::MethodProfiling)
          source_location = klass.instance_method(method).source_location
        elsif class_method
          ::AppOpticsAPM::Util.send_extend(klass, ::AppOpticsAPM::MethodProfiling)
          source_location = klass.method(method).source_location
        end

        report_kvs = collect_profile_kvs(klass, method, opts, extra_kvs, source_location)
        report_kvs[:MethodName] = safe_method_name

        if instance_method
          klass.class_eval do
            define_method(with_appoptics) do |*args, &block|
              profile_wrapper(without_appoptics, report_kvs, opts, *args, &block)
            end

            alias_method without_appoptics, method.to_s
            alias_method method.to_s, with_appoptics
          end
        elsif class_method
          klass.define_singleton_method(with_appoptics) do |*args, &block|
            profile_wrapper(without_appoptics, report_kvs, opts, *args, &block)
          end

          klass.singleton_class.class_eval do
            alias_method without_appoptics, method.to_s
            alias_method method.to_s, with_appoptics
          end
        end
        true
      end

      private

      ##
      # Private: Helper method to aggregate KVs to report
      #
      # klass  - the class or module that has the method to profile
      # method - the method to profile.  Can be singleton, instance, private etc...
      # opts   - a hash specifying the one or more of the following options:
      #   * :arguments  - report the arguments passed to <tt>method</tt> on each profile (default: false)
      #   * :result     - report the return value of <tt>method</tt> on each profile (default: false)
      #   * :backtrace  - report the return value of <tt>method</tt> on each profile (default: false)
      #   * :name       - alternate name for the profile reported in the dashboard (default: method name)
      # extra_kvs - a hash containing any additional KVs you would like reported with the profile
      # source_location - array returned from klass.method(:name).source_location
      #
      def collect_profile_kvs(klass, method, opts, extra_kvs, source_location)
        report_kvs = {}
        report_kvs[:Language] ||= :ruby
        report_kvs[:ProfileName] ||= opts[:name] ? opts[:name] : method

        if klass.is_a?(Class)
          report_kvs[:Class] = klass.to_s
        else
          report_kvs[:Module] = klass.to_s
        end

        # If this is a Rails Controller, report the KVs
        if defined?(::AbstractController::Base) && klass.ancestors.include?(::AbstractController::Base)
          report_kvs[:Controller] = klass.to_s
          report_kvs[:Action] = method.to_s
        end

        # We won't have access to this info for native methods (those not defined in Ruby).
        if source_location.is_a?(Array) && source_location.length == 2
          report_kvs[:File] = source_location[0]
          report_kvs[:LineNumber] = source_location[1]
        end

        # Merge in any extra_kvs requested
        report_kvs.merge!(extra_kvs)
      end


      # need to set the context to public, otherwise the following `extends` will be private in api.rb
      public

    end
  end
end
