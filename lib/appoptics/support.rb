# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'rbconfig'
require 'logger'

module AppOptics
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
    @logger_level = AppOptics.logger.level
    AppOptics.logger.level = ::Logger::DEBUG

    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn '* BEGIN AppOptics Support Report'
    AppOptics.logger.warn '*   Please email the output of this report to support@appoptics.com'
    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn "Ruby: #{RUBY_DESCRIPTION}"
    AppOptics.logger.warn "$0: #{$0}"
    AppOptics.logger.warn "$1: #{$1}" unless $1.nil?
    AppOptics.logger.warn "$2: #{$2}" unless $2.nil?
    AppOptics.logger.warn "$3: #{$3}" unless $3.nil?
    AppOptics.logger.warn "$4: #{$4}" unless $4.nil?
    AppOptics.logger.warn "AppOptics.loaded == #{AppOptics.loaded}"

    using_jruby = defined?(JRUBY_VERSION)
    AppOptics.logger.warn "Using JRuby?: #{yesno(using_jruby)}"
    if using_jruby
      AppOptics.logger.warn "Joboe Agent Status: #{Java::ComTracelyticsAgent::Agent.getStatus}"
    end

    on_heroku = AppOptics.heroku?
    AppOptics.logger.warn "On Heroku?: #{yesno(on_heroku)}"
    if on_heroku
      AppOptics.logger.warn "APPOPTICS_URL: #{ENV['APPOPTICS_URL']}"
    end

    AppOptics.logger.warn "AppOptics::Ruby defined?: #{yesno(defined?(AppOptics::Ruby))}"
    AppOptics.logger.warn "AppOptics.reporter: #{AppOptics.reporter}"

    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn '* Frameworks'
    AppOptics.logger.warn '********************************************************'

    using_rails = defined?(::Rails)
    AppOptics.logger.warn "Using Rails?: #{yesno(using_rails)}"
    if using_rails
      AppOptics.logger.warn "AppOptics::Rails loaded?: #{yesno(defined?(::AppOptics::Rails))}"
      AppOptics.logger.warn "AppOptics::Rack middleware loaded?: #{yesno(::Rails.configuration.middleware.include? AppOptics::Rack)}"
    end

    using_sinatra = defined?(::Sinatra)
    AppOptics.logger.warn "Using Sinatra?: #{yesno(using_sinatra)}"

    using_padrino = defined?(::Padrino)
    AppOptics.logger.warn "Using Padrino?: #{yesno(using_padrino)}"

    using_grape = defined?(::Grape)
    AppOptics.logger.warn "Using Grape?: #{yesno(using_grape)}"

    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn '* ActiveRecord Adapter'
    AppOptics.logger.warn '********************************************************'
    if defined?(::ActiveRecord)
      if defined?(::ActiveRecord::Base.connection.adapter_name)
        AppOptics.logger.warn "ActiveRecord adapter: #{::ActiveRecord::Base.connection.adapter_name}"
      end
    else
      AppOptics.logger.warn 'No ActiveRecord'
    end

    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn '* AppOptics Libraries'
    AppOptics.logger.warn '********************************************************'
    files = []
    ['/usr/lib/liboboe*', '/usr/lib64/liboboe*'].each do |d|
      files = Dir.glob(d)
      break if !files.empty?
    end
    if files.empty?
      AppOptics.logger.warn 'Error: No liboboe libs!'
    else
      files.each { |f|
        AppOptics.logger.warn f
      }
    end

    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn '* AppOptics::Config Values'
    AppOptics.logger.warn '********************************************************'
    AppOptics::Config.show.each { |k,v|
      AppOptics.logger.warn "#{k}: #{v}"
    }

    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn '* OS, Platform + Env'
    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn "host_os: " + RbConfig::CONFIG['host_os']
    AppOptics.logger.warn "sitearch: " + RbConfig::CONFIG['sitearch']
    AppOptics.logger.warn "arch: " + RbConfig::CONFIG['arch']
    AppOptics.logger.warn RUBY_PLATFORM
    AppOptics.logger.warn "RACK_ENV: #{ENV['RACK_ENV']}"
    AppOptics.logger.warn "RAILS_ENV: #{ENV['RAILS_ENV']}" if using_rails

    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn '* Raw __Init KVs'
    AppOptics.logger.warn '********************************************************'
    platform_info = AppOptics::Util.build_init_report
    platform_info.each { |k,v|
      AppOptics.logger.warn "#{k}: #{v}"
    }

    AppOptics.logger.warn '********************************************************'
    AppOptics.logger.warn '* END AppOptics Support Report'
    AppOptics.logger.warn '*   Support Email: support@appoptics.com'
    AppOptics.logger.warn '*   Github: https://github.com/tracelytics/ruby-appoptics'
    AppOptics.logger.warn '********************************************************'

    AppOptics.logger.level = @logger_level
    nil
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
end
