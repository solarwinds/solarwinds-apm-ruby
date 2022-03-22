# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

if SolarWindsAPM.loaded && defined?(ActiveSupport::Logger::SimpleFormatter)
  # even though SimpleFormatter inherits from Logger,
  # this will not append trace info twice,
  # because SimpleFormatter#call does not call super
  ActiveSupport::Logger::SimpleFormatter.send(:prepend, SolarWindsAPM::Logger::Formatter)
end


if SolarWindsAPM.loaded && defined?(ActiveSupport::TaggedLogging::Formatter)
  ActiveSupport::TaggedLogging::Formatter.send(:prepend, SolarWindsAPM::Logger::Formatter)
end
