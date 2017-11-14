# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'appoptics/frameworks/rails/inst/connection_adapters/mysql'
require 'appoptics/frameworks/rails/inst/connection_adapters/mysql2'
require 'appoptics/frameworks/rails/inst/connection_adapters/postgresql'

if AppOptics::Config[:active_record][:enabled] && !defined?(JRUBY_VERSION)
  begin
    adapter = ActiveRecord::Base.connection.adapter_name.downcase

    if Rails::VERSION::MAJOR < 5
      require 'appoptics/frameworks/rails/inst/connection_adapters/utils'
    else
      require 'appoptics/frameworks/rails/inst/connection_adapters/utils5x'
    end

    AppOptics::Inst::ConnectionAdapters::FlavorInitializers.mysql      if adapter == 'mysql'
    AppOptics::Inst::ConnectionAdapters::FlavorInitializers.mysql2     if adapter == 'mysql2'
    AppOptics::Inst::ConnectionAdapters::FlavorInitializers.postgresql if adapter == 'postgresql'

  rescue StandardError => e
    AppOptics.logger.error "[appoptics/error] AppOptics/ActiveRecord error: #{e.inspect}"
    AppOptics.logger.debug e.backtrace.join("\n")
  end
end
# vim:set expandtab:tabstop=2
