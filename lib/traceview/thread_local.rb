# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

module TraceView
  ##
  # Provides thread local storage for TraceView.
  #
  # Example usage:
  # module TraceViewBase
  #   extend ::TraceView::ThreadLocal
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
