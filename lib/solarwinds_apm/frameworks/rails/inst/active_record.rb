# Copyright (c) SolarWinds, LLC.
# All rights reserved.

require 'solarwinds_apm/frameworks/rails/inst/connection_adapters/mysql2'
require 'solarwinds_apm/frameworks/rails/inst/connection_adapters/postgresql'

if SolarWindsAPM::Config[:active_record][:enabled]
  begin
    SolarWindsAPM::Config[:verbose]
    adapter = if ActiveRecord::Base.respond_to?(:connection_db_config)
                ActiveRecord::Base.connection_db_config.adapter
              else
                ActiveRecord::Base.connection_config[:adapter]
              end

    require 'solarwinds_apm/frameworks/rails/inst/connection_adapters/utils5x'

    SolarWindsAPM::Inst::ConnectionAdapters::FlavorInitializers.mysql2     if adapter == 'mysql2'
    SolarWindsAPM::Inst::ConnectionAdapters::FlavorInitializers.postgresql if adapter =~ /postgresql|postgis/i

  rescue StandardError => e
    SolarWindsAPM.logger.error "[solarwinds_apm/error] SolarWindsAPM/ActiveRecord error: #{e.inspect}"
    SolarWindsAPM.logger.debug e.backtrace.join("\n")
  end
end
# vim:set expandtab:tabstop=2
