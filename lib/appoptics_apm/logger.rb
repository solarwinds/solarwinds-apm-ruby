# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'logger'

module AppOpticsAPM
  class << self
    attr_accessor :logger
  end
end

AppOpticsAPM.logger = Logger.new(STDERR)
# set log level to INFO to be consistent with the c-lib, DEBUG would be default
AppOpticsAPM.logger.level = Logger::INFO
