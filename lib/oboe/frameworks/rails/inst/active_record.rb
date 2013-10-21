# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'oboe/frameworks/rails/inst/connection_adapters/utils'
require 'oboe/frameworks/rails/inst/connection_adapters/mysql'
require 'oboe/frameworks/rails/inst/connection_adapters/mysql2'
require 'oboe/frameworks/rails/inst/connection_adapters/postgresql'
require 'oboe/frameworks/rails/inst/connection_adapters/oracle'

if Oboe::Config[:active_record][:enabled]
  begin
    adapter = ActiveRecord::Base::connection.adapter_name.downcase

    Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql      if adapter == "mysql"
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql2     if adapter == "mysql2"
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.postgresql if adapter == "postgresql"
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.oracle     if adapter == "oracleenhanced"

  rescue Exception => e
    Oboe.logger.error "[oboe/error] Oboe/ActiveRecord error: #{e.inspect}"
    Oboe.logger.debug e.backtrace.join("\n")
  end
end
# vim:set expandtab:tabstop=2
