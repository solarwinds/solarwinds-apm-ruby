# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require_relative 'logger_formatter'

if AppOpticsAPM.loaded && defined?(Lumberjack::Formatter)
  module Lumberjack
    class Formatter
      prepend AppOpticsAPM::Logger::Formatter
    end
  end
end

