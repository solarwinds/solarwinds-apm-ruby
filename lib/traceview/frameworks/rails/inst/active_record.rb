# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'traceview/frameworks/rails/inst/connection_adapters/mysql'
require 'traceview/frameworks/rails/inst/connection_adapters/mysql2'
require 'traceview/frameworks/rails/inst/connection_adapters/postgresql'

if TraceView::Config[:active_record][:enabled] && !defined?(JRUBY_VERSION)
  begin
    adapter = ActiveRecord::Base.connection.adapter_name.downcase

    if Rails::VERSION::MAJOR < 5
      require 'traceview/frameworks/rails/inst/connection_adapters/utils'
    else
      require 'traceview/frameworks/rails/inst/connection_adapters/utils5x'
    end

    TraceView::Inst::ConnectionAdapters::FlavorInitializers.mysql      if adapter == 'mysql'
    TraceView::Inst::ConnectionAdapters::FlavorInitializers.mysql2     if adapter == 'mysql2'
    TraceView::Inst::ConnectionAdapters::FlavorInitializers.postgresql if adapter == 'postgresql'

  rescue StandardError => e
    TraceView.logger.error "[traceview/error] TraceView/ActiveRecord error: #{e.inspect}"
    TraceView.logger.debug e.backtrace.join("\n")
  end
end
# vim:set expandtab:tabstop=2
