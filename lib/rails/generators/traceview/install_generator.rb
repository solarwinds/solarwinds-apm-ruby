# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.join(File.dirname(__FILE__), 'templates')
    desc "Copies a TraceView gem initializer file to your application."

    @namespace = "traceview:install"

    def copy_initializer
      # Set defaults
      @tracing_mode = 'through'
      @verbose = 'false'

      print_header

      while true do
        print_body

        user_tracing_mode = ask shell.set_color "* Tracing Mode? [through]:", :yellow
        user_tracing_mode.downcase!

        break if user_tracing_mode.blank?
        valid = ['always', 'through', 'never'].include?(user_tracing_mode)

        say shell.set_color "Valid values are 'always', 'through' or 'never'", :red, :bold unless valid
        if valid
          @tracing_mode = user_tracing_mode
          break
        end
      end

      print_footer

      template "traceview_initializer.rb", "config/initializers/traceview.rb"
    end

    private

      def print_header
        say ""
        say shell.set_color "Welcome to the TraceView Ruby instrumentation setup.", :green, :bold
        say ""
        say "To instrument your Rails application, you can setup your tracing strategy here."
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

      def print_body
        say ""
        say shell.set_color "Tracing Mode", :magenta
        say "------------"
        say "Tracing Mode determines when traces should be initiated for incoming requests.  Valid"
        say "options are #{shell.set_color "always", :yellow}, #{shell.set_color "through", :yellow} (when using an instrumented Apache or Nginx) and #{shell.set_color "never", :yellow}."
        say ""
        say "If you're not using an instrumented Apache or Nginx, set this directive to #{shell.set_color "always", :yellow} in"
        say "order to initiate tracing from Ruby."
        say ""
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
