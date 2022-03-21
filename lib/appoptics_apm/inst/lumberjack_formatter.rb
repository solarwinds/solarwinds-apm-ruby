# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require_relative 'logger_formatter'

if SolarWindsAPM.loaded && defined?(Lumberjack::Formatter)
  Lumberjack::Formatter.send(:prepend, SolarWindsAPM::Logger::Formatter)
end

