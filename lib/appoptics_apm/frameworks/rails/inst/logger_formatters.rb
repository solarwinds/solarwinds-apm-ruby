# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

if AppOpticsAPM.loaded && defined?(ActiveSupport::Logger::SimpleFormatter)
  # even though SimpleFormatter inherits from Logger,
  # this will not append trace info twice,
  # because SimpleFormatter#call does not call super
  ActiveSupport::Logger::SimpleFormatter.send(:prepend, AppOpticsAPM::Logger::Formatter)
end


if AppOpticsAPM.loaded && defined?(ActiveSupport::TaggedLogging::Formatter)
  ActiveSupport::TaggedLogging::Formatter.send(:prepend, AppOpticsAPM::Logger::Formatter)
end
