# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require_relative 'logger_formatter'

if AppOpticsAPM.loaded && defined?(Lumberjack::Formatter)
  Lumberjack::Formatter.send(:prepend, AppOpticsAPM::Logger::Formatter)
end

