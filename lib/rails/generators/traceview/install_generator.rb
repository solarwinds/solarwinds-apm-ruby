# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.join(File.dirname(__FILE__), 'templates')
    desc "Copies a TraceView gem initializer file to your application."

    @namespace = "traceview:install"

    def copy_initializer
      # Set defaults
      @verbose = 'false'

      print_header
      print_footer

      template "traceview_initializer.rb", "config/initializers/traceview.rb"
    end

    private

      def print_header
        say ""
        say shell.set_color "Welcome to the TraceView Ruby instrumentation setup.", :green, :bold
        say ""
        say shell.set_color "Documentation Links", :magenta
        say "-------------------"
        say ""
        say "TraceView Installation Overview:"
        say "http://docs.traceview.solarwinds.com/TraceView/install-instrumentation.html"
        say ""
        say "More information on instrumenting Ruby applications can be found here:"
        say "http://docs.traceview.solarwinds.com/Instrumentation/ruby.html#installing-ruby-instrumentation"
      end

      def print_footer
        say ""
        say "You can change configuration values in the future by modifying config/initializers/traceview.rb"
        say ""
        say "Thanks! Creating the TraceView initializer..."
        say ""
      end
  end
end
