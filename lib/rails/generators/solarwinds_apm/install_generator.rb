# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.join(File.dirname(__FILE__), 'templates')
    desc "Copies a SolarWindsAPM gem initializer file to your application."

    @namespace = "solarwinds_apm:install"

    def copy_initializer
      # Set defaults
      @verbose = 'false'

      print_header
      print_footer

      template "solarwinds_apm_initializer.rb", "config/initializers/solarwinds_apm.rb"
    end

    private

    # rubocop:disable Metrics/MethodLength
    def print_header
      say ""
      say shell.set_color "Welcome to the SolarWindsAPM Ruby instrumentation setup.", :green, :bold
      say ""
      say shell.set_color "Documentation Links", :magenta
      say "-------------------"
      say ""
      say "SolarWindsAPM Installation Overview:"
      say "https://documentation.solarwinds.com/en/success_center/swaas/"
      say ""
      say "More information on instrumenting Ruby applications can be found here:"
      say "https://documentation.solarwinds.com/en/success_center/swaas/default.htm#cshid=app-add-ruby-agent"
    end
    # rubocop:enable Metrics/MethodLength

    def print_footer
      say ""
      say "You can change configuration values in the future by modifying config/initializers/solarwinds_apm.rb"
      say ""
      say "Thanks! Creating the SolarWindsAPM initializer..."
      say ""
    end
  end
end
