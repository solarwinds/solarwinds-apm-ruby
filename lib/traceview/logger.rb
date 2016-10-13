# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'logger'

module TraceView
  class << self
    attr_accessor :logger
  end

  class Logger
    # Fatal message
    def fatal(string, exception = nil)
      TraceView.logger.fatal(string) if TraceView.logger
    end

    # Error message
    def error(msg, exception = nil)
      TraceView.logger.error(string) if TraceView.logger
    end

    # Warn message
    def warn(msg, exception = nil)
      TraceView.logger.warn(string) if TraceView.logger
    end

    # Info message
    def info(msg, exception = nil)
      TraceView.logger.info(string) if TraceView.logger
    end

    # Debug message
    def debug(msg, exception = nil)
      TraceView.logger.debug(string) if TraceView.logger
    end

  end
end

TraceView.logger = Logger.new(STDERR)

