# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'appoptics_apm/frameworks/rails/inst/connection_adapters/mysql'
require 'appoptics_apm/frameworks/rails/inst/connection_adapters/mysql2'
require 'appoptics_apm/frameworks/rails/inst/connection_adapters/postgresql'

if AppOpticsAPM::Config[:active_record][:enabled] && !defined?(JRUBY_VERSION) && Rails::VERSION::MAJOR < 6
  begin
    adapter = ActiveRecord::Base.connection_config[:adapter]

    if Rails::VERSION::MAJOR < 5
      require 'appoptics_apm/frameworks/rails/inst/connection_adapters/utils'
    elsif Rails::VERSION::MAJOR == 5
      require 'appoptics_apm/frameworks/rails/inst/connection_adapters/utils5x'
    end

    AppOpticsAPM::Inst::ConnectionAdapters::FlavorInitializers.mysql      if adapter == 'mysql'
    AppOpticsAPM::Inst::ConnectionAdapters::FlavorInitializers.mysql2     if adapter == 'mysql2'
    AppOpticsAPM::Inst::ConnectionAdapters::FlavorInitializers.postgresql if adapter == 'postgresql'

  rescue StandardError => e
    AppOpticsAPM.logger.error "[appoptics_apm/error] AppOpticsAPM/ActiveRecord error: #{e.inspect}"
    AppOpticsAPM.logger.debug e.backtrace.join("\n")
  end
end
# vim:set expandtab:tabstop=2
