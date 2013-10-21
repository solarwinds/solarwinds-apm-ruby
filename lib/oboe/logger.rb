# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'logger'

module Oboe
  class << self
    attr_accessor :logger
  end

  class Logger
    # Fatal message
    def fatal(string, exception = nil)
      Oboe.logger.fatal(string) if Oboe.logger
    end
    
    # Error message
    def error(msg, exception = nil)
      Oboe.logger.error(string) if Oboe.logger
    end
    
    # Warn message
    def warn(msg, exception = nil)
      Oboe.logger.warn(string) if Oboe.logger
    end
    
    # Info message
    def info(msg, exception = nil)
      Oboe.logger.info(string) if Oboe.logger
    end
    
    # Debug message
    def debug(msg, exception = nil)
      Oboe.logger.debug(string) if Oboe.logger
    end

  end
end

Oboe.logger = Logger.new(STDERR)

