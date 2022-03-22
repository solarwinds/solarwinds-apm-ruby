# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  ##
  # Provides thread local storage for SolarWindsAPM.
  #
  # Example usage:
  # module SolarWindsAPMBase
  #   extend SolarWindsAPM::ThreadLocal
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
