# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'logger'

module AppOpticsAPM
  class << self
    attr_accessor :logger
  end

  # TODO ME currently unused, keeping it around for xtrace logging epic
  # class Logger
  #   # Fatal message
  #   def fatal(msg, exception = nil)
  #     AppOpticsAPM.logger.fatal(msg) if AppOpticsAPM.logger
  #   end
  #
  #   # Error message
  #   def error(msg, exception = nil)
  #     AppOpticsAPM.logger.error(msg) if AppOpticsAPM.logger
  #   end
  #
  #   # Warn message
  #   def warn(msg, exception = nil)
  #     AppOpticsAPM.logger.warn(msg) if AppOpticsAPM.logger
  #   end
  #
  #   # Info message
  #   def info(msg, exception = nil)
  #     AppOpticsAPM.logger.info(msg) if AppOpticsAPM.logger
  #   end
  #
  #   # Debug message
  #   def debug(msg, exception = nil)
  #     AppOpticsAPM.logger.debug(msg) if AppOpticsAPM.logger
  #   end
  #
  # end
end

# Using the currently defined Logger, e.g. the Rails logger
AppOpticsAPM.logger = Logger.new(STDERR)
# set log level to INFO to be consistent with the c-lib, DEBUG would be default
AppOpticsAPM.logger.level = Logger::INFO
