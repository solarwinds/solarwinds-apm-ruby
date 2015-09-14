# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Test
    class << self
      def load_extras
        # If we're using the libraries gemfile (with sidekiq and resque)
        if File.basename(ENV['BUNDLE_GEMFILE']) =~ /libraries/
          # Load all of the test workers
          pattern = File.join(File.dirname(__FILE__), '../../test/jobs/', '*.rb')
          Dir.glob(pattern) do |f|
            TV.logger.debug "Loading test job file: #{f}"
            require f
          end
        end
      end
    end
  end
end
