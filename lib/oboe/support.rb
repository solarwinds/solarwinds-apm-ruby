# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

module Oboe
  ##
  # This module is used to debug problematic setups and/or environments.
  #

  def self.yesno(x)
    x ? "yes" : "no"
  end

  def self.investigate
    Oboe.logger.warn "Ruby: #{RUBY_DESCRIPTION}"
    Oboe.logger.warn "$0: #{$0}"
    Oboe.logger.warn "$1: #{$1}" unless $1.nil?
    Oboe.logger.warn "$2: #{$2}" unless $2.nil?
    Oboe.logger.warn "Oboe.loaded == #{Oboe.loaded}"

    using_jruby = defined?(JRUBY_VERSION)
    Oboe.logger.warn "Using JRuby?: #{yesno(using_jruby)}"
    if using_jruby
      Oboe.logger.warn "Joboe Agent Status: #{Java::ComTracelyticsAgent::Agent.getStatus}"
    end

    on_heroku = Oboe.heroku?
    Oboe.logger.warn "On Heroku?: #{yesno(on_heroku)}"
    if on_heroku
      Oboe.logger.warn "TRACEVIEW_URL: #{ENV['TRACEVIEW_URL']}"
    end

    using_rails = defined?(::Rails)
    Oboe.logger.warn "Using Rails?: #{yesno(using_rails)}"
    if using_rails
      Oboe.logger.warn "Rails Version: #{Rails.version}"
      Oboe.logger.warn "Oboe::Rails loaded?: #{defined?(::Oboe::Rails)}"
    end

    using_sinatra = defined?(::Sinatra)
    Oboe.logger.warn "Using Sinatra?: #{yesno(using_sinatra)}"

    using_padrino = defined?(::Padrino)
    Oboe.logger.warn "Using Padrino?: #{yesno(using_padrino)}"

    using_grape = defined?(::Grape)
    Oboe.logger.warn "Using Grape?: #{yesno(using_grape)}"

    Oboe.logger.warn "Using Redis?: #{yesno(defined?(::Redis))}"

    Oboe.logger.warn "Oboe::Ruby defined?: #{yesno(defined?(Oboe::Ruby))}"

    platform_info = Oboe::Util.build_report
    platform_info.each { |k,v|
      Oboe.logger.warn "#{k}: #{v}"
    }
    nil
  end
end
