# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.join(File.dirname(__FILE__), 'templates')
    desc "Copies a AppOpticsAPM gem initializer file to your application."

    @namespace = "appoptics_apm:install"

    def copy_initializer
      # Set defaults
      @verbose = 'false'

      print_header
      print_footer

      template "appoptics_apm_initializer.rb", "config/initializers/appoptics_apm.rb"
    end

    private

      def print_header
        say ""
        say shell.set_color "Welcome to the AppOpticsAPM Ruby instrumentation setup.", :green, :bold
        say ""
        say shell.set_color "Documentation Links", :magenta
        say "-------------------"
        say ""
        say "AppOpticsAPM Installation Overview:"
        say "http://docs.appoptics.solarwinds.com/AppOpticsAPM/install-instrumentation.html"
        say ""
        say "More information on instrumenting Ruby applications can be found here:"
        say "http://docs.appoptics.solarwinds.com/Instrumentation/ruby.html#installing-ruby-instrumentation"
      end

      def print_footer
        say ""
        say "You can change configuration values in the future by modifying config/initializers/appoptics_apm.rb"
        say ""
        say "Thanks! Creating the AppOpticsAPM initializer..."
        say ""
      end
  end
end
