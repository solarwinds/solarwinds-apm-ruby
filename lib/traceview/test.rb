# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Test
    class << self
      ##
      # load_extras
      #
      # This method simply loads all the extras needed to run
      # tests such as models, jobs etc...
      #
      def load_extras
        # If we're using the libraries gemfile (with sidekiq and resque)
        if TV::Test.gemfile?(:libraries)
          # Load all of the test workers
          pattern = File.join(File.dirname(__FILE__), '../../test/jobs/**/', '*.rb')
          Dir.glob(pattern) do |f|
            TV.logger.debug "Loading test job file: #{File.basename(f)}"
            require f
          end
        end
      end

      ##
      # gemfile?
      #
      # Method used to determine under which gemfile we're running.
      # Pass <tt>name</tt> as the gemfile name only (without the
      # .gemfile extension)
      #
      # returns true or fase depending on result
      #
      def gemfile?(name)
        File.basename(ENV['BUNDLE_GEMFILE']) == (name.to_s + '.gemfile')
      end

      ##
      # gemfile
      #
      # Used to determine under which gemfile we are running.  This
      # method will return the name of the active gemfile
      #
      def gemfile
        File.basename(ENV['BUNDLE_GEMFILE']).split('.').first
      end
    end
  end
end
