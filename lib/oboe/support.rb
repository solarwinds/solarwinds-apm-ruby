# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

module Oboe
  ##
  # This module is used to debug problematic setups and/or environments.
  # Depending on the environment, output may be to stdout or the framework
  # log file (e.g. log/production.log)

  ##
  # yesno
  #
  # Utility method to translate value/nil to "yes"/"no" strings
  def self.yesno(x)
    x ? "yes" : "no"
  end

  def self.support_report
    Oboe.logger.warn "********************************************************"
    Oboe.logger.warn "* BEGIN TraceView Support Report"
    Oboe.logger.warn "*   Please email the output of this report to traceviewsupport@appneta.com"
    Oboe.logger.warn "********************************************************"
    Oboe.logger.warn "Ruby: #{RUBY_DESCRIPTION}"
    Oboe.logger.warn "$0: #{$0}"
    Oboe.logger.warn "$1: #{$1}" unless $1.nil?
    Oboe.logger.warn "$2: #{$2}" unless $2.nil?
    Oboe.logger.warn "$3: #{$3}" unless $3.nil?
    Oboe.logger.warn "$4: #{$4}" unless $4.nil?
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

    Oboe.logger.warn "Oboe::Ruby defined?: #{yesno(defined?(Oboe::Ruby))}"
    Oboe.logger.warn "Oboe.reporter: #{Oboe.reporter}"

    Oboe.logger.warn "********************************************************"
    Oboe.logger.warn "* Frameworks"
    Oboe.logger.warn "********************************************************"

    using_rails = defined?(::Rails)
    Oboe.logger.warn "Using Rails?: #{yesno(using_rails)}"
    if using_rails
      Oboe.logger.warn "Oboe::Rails loaded?: #{yesno(defined?(::Oboe::Rails))}"
    end

    using_sinatra = defined?(::Sinatra)
    Oboe.logger.warn "Using Sinatra?: #{yesno(using_sinatra)}"

    using_padrino = defined?(::Padrino)
    Oboe.logger.warn "Using Padrino?: #{yesno(using_padrino)}"

    using_grape = defined?(::Grape)
    Oboe.logger.warn "Using Grape?: #{yesno(using_grape)}"

    Oboe.logger.warn "********************************************************"
    Oboe.logger.warn "* TraceView Libraries"
    Oboe.logger.warn "********************************************************"
    files = Dir.glob('/usr/lib/liboboe*')
    if files.empty?
      Oboe.logger.warn "Error: No liboboe libs!"
    else
      files.each { |f|
        Oboe.logger.warn f
      }
    end

    Oboe.logger.warn "********************************************************"
    Oboe.logger.warn "* Raw __Init KVs"
    Oboe.logger.warn "********************************************************"
    platform_info = Oboe::Util.build_report
    platform_info.each { |k,v|
      Oboe.logger.warn "#{k}: #{v}"
    }
    
    Oboe.logger.warn "********************************************************"
    Oboe.logger.warn "* END TraceView Support Report"
    Oboe.logger.warn "*   Support Email: traceviewsupport@appneta.com"
    Oboe.logger.warn "*   Support Portal: https://support.tv.appneta.com"
    Oboe.logger.warn "*   Freenode IRC: #appneta"
    Oboe.logger.warn "*   Github: https://github.com/appneta/oboe-ruby"
    Oboe.logger.warn "********************************************************"
    nil
  end
end
