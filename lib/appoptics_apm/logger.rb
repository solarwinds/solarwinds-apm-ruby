# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'logger'

module AppOpticsAPM
  class << self
    attr_accessor :logger
  end

  class Logger
    # Fatal message
    def fatal(string, exception = nil)
      AppOpticsAPM.logger.fatal(string) if AppOpticsAPM.logger
    end

    # Error message
    def error(msg, exception = nil)
      AppOpticsAPM.logger.error(string) if AppOpticsAPM.logger
    end

    # Warn message
    def warn(msg, exception = nil)
      AppOpticsAPM.logger.warn(string) if AppOpticsAPM.logger
    end

    # Info message
    def info(msg, exception = nil)
      AppOpticsAPM.logger.info(string) if AppOpticsAPM.logger
    end

    # Debug message
    def debug(msg, exception = nil)
      AppOpticsAPM.logger.debug(string) if AppOpticsAPM.logger
    end

  end
end

AppOpticsAPM.logger = Logger.new(STDERR)

