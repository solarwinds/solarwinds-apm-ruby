# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  ##
  # Provides thread local storage for AppOptics.
  #
  # Example usage:
  # module AppOpticsBase
  #   extend ::AppOptics::ThreadLocal
  #   thread_local :layer_op
  # end
  module ThreadLocal
    def thread_local(name)
      key = "__#{self}_#{name}__".intern

      define_method(name) do
        Thread.current[key]
      end

      define_method(name.to_s + '=') do |value|
        Thread.current[key] = value
      end
    end
  end
end
