# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'rbconfig'
require 'logger'

module SolarWindsAPM
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
    @logger_level = SolarWindsAPM.logger.level
    SolarWindsAPM.logger.level = ::Logger::DEBUG

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* BEGIN SolarWindsAPM Support Report'
    SolarWindsAPM.logger.warn '*   Please email the output of this report to technicalsupport@solarwinds.com'
    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn "Ruby: #{RUBY_DESCRIPTION}"
    SolarWindsAPM.logger.warn "$0: #{$0}"
    SolarWindsAPM.logger.warn "$1: #{$1}" unless $1.nil?
    SolarWindsAPM.logger.warn "$2: #{$2}" unless $2.nil?
    SolarWindsAPM.logger.warn "$3: #{$3}" unless $3.nil?
    SolarWindsAPM.logger.warn "$4: #{$4}" unless $4.nil?
    SolarWindsAPM.logger.warn "SolarWindsAPM.loaded == #{SolarWindsAPM.loaded}"

    on_heroku = SolarWindsAPM.heroku?
    SolarWindsAPM.logger.warn "On Heroku?: #{yesno(on_heroku)}"
    if on_heroku
      SolarWindsAPM.logger.warn "SW_APM_URL: #{ENV['SW_APM_URL']}"
    end

    SolarWindsAPM.logger.warn "SolarWindsAPM::Ruby defined?: #{yesno(defined?(SolarWindsAPM::Ruby))}"
    SolarWindsAPM.logger.warn "SolarWindsAPM.reporter: #{SolarWindsAPM.reporter}"

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* Frameworks'
    SolarWindsAPM.logger.warn '********************************************************'

    using_rails = defined?(::Rails)
    SolarWindsAPM.logger.warn "Using Rails?: #{yesno(using_rails)}"
    if using_rails
      SolarWindsAPM.logger.warn "SolarWindsAPM::Rails loaded?: #{yesno(defined?(SolarWindsAPM::Rails))}"
      if defined?(SolarWindsAPM::Rack)
        SolarWindsAPM.logger.warn "SolarWindsAPM::Rack middleware loaded?: #{yesno(::Rails.configuration.middleware.include? SolarWindsAPM::Rack)}"
      end
    end

    using_sinatra = defined?(::Sinatra)
    SolarWindsAPM.logger.warn "Using Sinatra?: #{yesno(using_sinatra)}"

    using_padrino = defined?(::Padrino)
    SolarWindsAPM.logger.warn "Using Padrino?: #{yesno(using_padrino)}"

    using_grape = defined?(::Grape)
    SolarWindsAPM.logger.warn "Using Grape?: #{yesno(using_grape)}"

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* ActiveRecord Adapter'
    SolarWindsAPM.logger.warn '********************************************************'
    if defined?(::ActiveRecord)
      if defined?(::ActiveRecord::Base.connection.adapter_name)
        SolarWindsAPM.logger.warn "ActiveRecord adapter: #{::ActiveRecord::Base.connection.adapter_name}"
      end
    else
      SolarWindsAPM.logger.warn 'No ActiveRecord'
    end

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* SolarWindsAPM::Config Values'
    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM::Config.print_config

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* OS, Platform + Env'
    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn "host_os: " + RbConfig::CONFIG['host_os']
    SolarWindsAPM.logger.warn "sitearch: " + RbConfig::CONFIG['sitearch']
    SolarWindsAPM.logger.warn "arch: " + RbConfig::CONFIG['arch']
    SolarWindsAPM.logger.warn RUBY_PLATFORM
    SolarWindsAPM.logger.warn "RACK_ENV: #{ENV['RACK_ENV']}"
    SolarWindsAPM.logger.warn "RAILS_ENV: #{ENV['RAILS_ENV']}" if using_rails

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* Raw __Init KVs'
    SolarWindsAPM.logger.warn '********************************************************'
    platform_info = SolarWindsAPM::Util.build_init_report
    platform_info.each { |k,v|
      SolarWindsAPM.logger.warn "#{k}: #{v}"
    }

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* END SolarWindsAPM Support Report'
    SolarWindsAPM.logger.warn '*   Support Email: technicalsupport@solarwinds.com'
    SolarWindsAPM.logger.warn '*   Github: https://github.com/librato/ruby-solarwinds'
    SolarWindsAPM.logger.warn '********************************************************'

    SolarWindsAPM.logger.level = @logger_level
    nil
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
end
