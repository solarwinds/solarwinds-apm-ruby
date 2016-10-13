# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'rbconfig'
require 'logger'

module TraceView
  ##
  # This module is used to debug problematic setups and/or environments.
  # Depending on the environment, output may be to stdout or the framework
  # log file (e.g. log/production.log)

  ##
  # yesno
  #
  # Utility method to translate value/nil to "yes"/"no" strings
  def self.yesno(x)
    x ? 'yes' : 'no'
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
  def self.support_report
    @logger_level = TraceView.logger.level
    TraceView.logger.level = ::Logger::DEBUG

    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn '* BEGIN TraceView Support Report'
    TraceView.logger.warn '*   Please email the output of this report to traceviewsupport@appneta.com'
    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn "Ruby: #{RUBY_DESCRIPTION}"
    TraceView.logger.warn "$0: #{$0}"
    TraceView.logger.warn "$1: #{$1}" unless $1.nil?
    TraceView.logger.warn "$2: #{$2}" unless $2.nil?
    TraceView.logger.warn "$3: #{$3}" unless $3.nil?
    TraceView.logger.warn "$4: #{$4}" unless $4.nil?
    TraceView.logger.warn "TraceView.loaded == #{TraceView.loaded}"

    using_jruby = defined?(JRUBY_VERSION)
    TraceView.logger.warn "Using JRuby?: #{yesno(using_jruby)}"
    if using_jruby
      TraceView.logger.warn "Joboe Agent Status: #{Java::ComTracelyticsAgent::Agent.getStatus}"
    end

    on_heroku = TraceView.heroku?
    TraceView.logger.warn "On Heroku?: #{yesno(on_heroku)}"
    if on_heroku
      TraceView.logger.warn "TRACEVIEW_URL: #{ENV['TRACEVIEW_URL']}"
    end

    TraceView.logger.warn "TraceView::Ruby defined?: #{yesno(defined?(TraceView::Ruby))}"
    TraceView.logger.warn "TraceView.reporter: #{TraceView.reporter}"

    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn '* Frameworks'
    TraceView.logger.warn '********************************************************'

    using_rails = defined?(::Rails)
    TraceView.logger.warn "Using Rails?: #{yesno(using_rails)}"
    if using_rails
      TraceView.logger.warn "TraceView::Rails loaded?: #{yesno(defined?(::TraceView::Rails))}"
      TraceView.logger.warn "TraceView::Rack middleware loaded?: #{yesno(::Rails.configuration.middleware.include? TraceView::Rack)}"
    end

    using_sinatra = defined?(::Sinatra)
    TraceView.logger.warn "Using Sinatra?: #{yesno(using_sinatra)}"

    using_padrino = defined?(::Padrino)
    TraceView.logger.warn "Using Padrino?: #{yesno(using_padrino)}"

    using_grape = defined?(::Grape)
    TraceView.logger.warn "Using Grape?: #{yesno(using_grape)}"

    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn '* ActiveRecord Adapter'
    TraceView.logger.warn '********************************************************'
    if defined?(::ActiveRecord)
      if defined?(::ActiveRecord::Base.connection.adapter_name)
        TraceView.logger.warn "ActiveRecord adapter: #{::ActiveRecord::Base.connection.adapter_name}"
      end
    else
      TraceView.logger.warn 'No ActiveRecord'
    end

    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn '* TraceView Libraries'
    TraceView.logger.warn '********************************************************'
    files = []
    ['/usr/lib/liboboe*', '/usr/lib64/liboboe*'].each do |d|
      files = Dir.glob(d)
      break if !files.empty?
    end
    if files.empty?
      TraceView.logger.warn 'Error: No liboboe libs!'
    else
      files.each { |f|
        TraceView.logger.warn f
      }
    end

    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn '* TraceView::Config Values'
    TraceView.logger.warn '********************************************************'
    TraceView::Config.show.each { |k,v|
      TraceView.logger.warn "#{k}: #{v}"
    }

    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn '* OS, Platform + Env'
    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn "host_os: " + RbConfig::CONFIG['host_os']
    TraceView.logger.warn "sitearch: " + RbConfig::CONFIG['sitearch']
    TraceView.logger.warn "arch: " + RbConfig::CONFIG['arch']
    TraceView.logger.warn RUBY_PLATFORM
    TraceView.logger.warn "RACK_ENV: #{ENV['RACK_ENV']}"
    TraceView.logger.warn "RAILS_ENV: #{ENV['RAILS_ENV']}" if using_rails

    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn '* Raw __Init KVs'
    TraceView.logger.warn '********************************************************'
    platform_info = TraceView::Util.build_init_report
    platform_info.each { |k,v|
      TraceView.logger.warn "#{k}: #{v}"
    }

    TraceView.logger.warn '********************************************************'
    TraceView.logger.warn '* END TraceView Support Report'
    TraceView.logger.warn '*   Support Email: traceviewsupport@appneta.com'
    TraceView.logger.warn '*   Support Portal: https://tickets.appneta.com'
    TraceView.logger.warn '*   Freenode IRC: #appneta'
    TraceView.logger.warn '*   Github: https://github.com/appneta/ruby-traceview'
    TraceView.logger.warn '********************************************************'

    TraceView.logger.level = @logger_level
    nil
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
end
