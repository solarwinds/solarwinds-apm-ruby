# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module API
    ##
    # Module that provides profiling of arbitrary blocks of code
    module Profiling
      ##
      # Public: Profile a given block of code. Detect any exceptions thrown by
      # the block and report errors.
      #
      # profile_name - A name used to identify the block being profiled.
      # report_kvs - A hash containing key/value pairs that will be reported along
      #              with the event of this profile (optional).
      # with_backtrace - Boolean to indicate whether a backtrace should
      #                  be collected with this trace event.
      #
      # Example
      #
      #   def computation(n)
      #     Oboe::API.profile('fib', { :n => n }) do
      #       fib(n)
      #     end
      #   end
      #
      # Returns the result of the block.
      def profile(profile_name, report_kvs = {}, with_backtrace = false)
        report_kvs[:Language] ||= :ruby
        report_kvs[:ProfileName] ||= profile_name
        report_kvs[:Backtrace] = Oboe::API.backtrace if with_backtrace

        Oboe::API.log(nil, 'profile_entry', report_kvs)

        begin
          yield
        rescue => e
          log_exception(nil, e)
          raise
        ensure
          exit_kvs = {}
          exit_kvs[:Language] = :ruby
          exit_kvs[:ProfileName] = report_kvs[:ProfileName]

          Oboe::API.log(nil, 'profile_exit', exit_kvs)
        end
      end
    end
  end
end
