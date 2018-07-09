# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'rbconfig'
require 'logger'

module AppOpticsAPM
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
    @logger_level = AppOpticsAPM.logger.level
    AppOpticsAPM.logger.level = ::Logger::DEBUG

    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn '* BEGIN AppOpticsAPM Support Report'
    AppOpticsAPM.logger.warn '*   Please email the output of this report to support@appoptics.com'
    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn "Ruby: #{RUBY_DESCRIPTION}"
    AppOpticsAPM.logger.warn "$0: #{$0}"
    AppOpticsAPM.logger.warn "$1: #{$1}" unless $1.nil?
    AppOpticsAPM.logger.warn "$2: #{$2}" unless $2.nil?
    AppOpticsAPM.logger.warn "$3: #{$3}" unless $3.nil?
    AppOpticsAPM.logger.warn "$4: #{$4}" unless $4.nil?
    AppOpticsAPM.logger.warn "AppOpticsAPM.loaded == #{AppOpticsAPM.loaded}"

    using_jruby = defined?(JRUBY_VERSION)
    AppOpticsAPM.logger.warn "Using JRuby?: #{yesno(using_jruby)}"
    if using_jruby
      AppOpticsAPM.logger.warn "Joboe Agent Status: #{Java::ComTracelyticsAgent::Agent.getStatus}"
    end

    on_heroku = AppOpticsAPM.heroku?
    AppOpticsAPM.logger.warn "On Heroku?: #{yesno(on_heroku)}"
    if on_heroku
      AppOpticsAPM.logger.warn "APPOPTICS_URL: #{ENV['APPOPTICS_URL']}"
    end

    AppOpticsAPM.logger.warn "AppOpticsAPM::Ruby defined?: #{yesno(defined?(AppOpticsAPM::Ruby))}"
    AppOpticsAPM.logger.warn "AppOpticsAPM.reporter: #{AppOpticsAPM.reporter}"

    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn '* Frameworks'
    AppOpticsAPM.logger.warn '********************************************************'

    using_rails = defined?(::Rails)
    AppOpticsAPM.logger.warn "Using Rails?: #{yesno(using_rails)}"
    if using_rails
      AppOpticsAPM.logger.warn "AppOpticsAPM::Rails loaded?: #{yesno(defined?(::AppOpticsAPM::Rails))}"
      if defined?(::AppOpticsAPM::Rack)
        AppOpticsAPM.logger.warn "AppOpticsAPM::Rack middleware loaded?: #{yesno(::Rails.configuration.middleware.include? AppOpticsAPM::Rack)}"
      end
    end

    using_sinatra = defined?(::Sinatra)
    AppOpticsAPM.logger.warn "Using Sinatra?: #{yesno(using_sinatra)}"

    using_padrino = defined?(::Padrino)
    AppOpticsAPM.logger.warn "Using Padrino?: #{yesno(using_padrino)}"

    using_grape = defined?(::Grape)
    AppOpticsAPM.logger.warn "Using Grape?: #{yesno(using_grape)}"

    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn '* ActiveRecord Adapter'
    AppOpticsAPM.logger.warn '********************************************************'
    if defined?(::ActiveRecord)
      if defined?(::ActiveRecord::Base.connection.adapter_name)
        AppOpticsAPM.logger.warn "ActiveRecord adapter: #{::ActiveRecord::Base.connection.adapter_name}"
      end
    else
      AppOpticsAPM.logger.warn 'No ActiveRecord'
    end

    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn '* AppOpticsAPM::Config Values'
    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM::Config.print_config

    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn '* OS, Platform + Env'
    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn "host_os: " + RbConfig::CONFIG['host_os']
    AppOpticsAPM.logger.warn "sitearch: " + RbConfig::CONFIG['sitearch']
    AppOpticsAPM.logger.warn "arch: " + RbConfig::CONFIG['arch']
    AppOpticsAPM.logger.warn RUBY_PLATFORM
    AppOpticsAPM.logger.warn "RACK_ENV: #{ENV['RACK_ENV']}"
    AppOpticsAPM.logger.warn "RAILS_ENV: #{ENV['RAILS_ENV']}" if using_rails

    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn '* Raw __Init KVs'
    AppOpticsAPM.logger.warn '********************************************************'
    platform_info = AppOpticsAPM::Util.build_init_report
    platform_info.each { |k,v|
      AppOpticsAPM.logger.warn "#{k}: #{v}"
    }

    AppOpticsAPM.logger.warn '********************************************************'
    AppOpticsAPM.logger.warn '* END AppOpticsAPM Support Report'
    AppOpticsAPM.logger.warn '*   Support Email: support@appoptics.com'
    AppOpticsAPM.logger.warn '*   Github: https://github.com/librato/ruby-appoptics'
    AppOpticsAPM.logger.warn '********************************************************'

    AppOpticsAPM.logger.level = @logger_level
    nil
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
end
