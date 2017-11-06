# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'logger'

module AppOptics
  class << self
    attr_accessor :logger
  end

  class Logger
    # Fatal message
    def fatal(string, exception = nil)
      AppOptics.logger.fatal(string) if AppOptics.logger
    end

    # Error message
    def error(msg, exception = nil)
      AppOptics.logger.error(string) if AppOptics.logger
    end

    # Warn message
    def warn(msg, exception = nil)
      AppOptics.logger.warn(string) if AppOptics.logger
    end

    # Info message
    def info(msg, exception = nil)
      AppOptics.logger.info(string) if AppOptics.logger
    end

    # Debug message
    def debug(msg, exception = nil)
      AppOptics.logger.debug(string) if AppOptics.logger
    end

  end
end

AppOptics.logger = Logger.new(STDERR)

