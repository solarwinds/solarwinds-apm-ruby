# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'logger'

module SolarWindsAPM
  class << self
    attr_accessor :logger
  end
end

SolarWindsAPM.logger = Logger.new(STDERR)
# set log level to INFO to be consistent with the c-lib, DEBUG would be default
SolarWindsAPM.logger.level = Logger::INFO
