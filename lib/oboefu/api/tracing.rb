module Oboe
  module API
    module Tracing
      def trace(layer, opts={})
        log_entry(layer, opts)
        begin 
          yield
        rescue Exception => e
          log_exception(layer, e)
        ensure
          log_exit(layer)
        end
      end
  
      def start_trace(layer, opts={})
        log_start(layer, nil, opts)
        begin
          result = yield
          xtrace = Oboe::API.log_end(layer)
          [result, xtrace]
        rescue Exception => e
          log_exception(layer, e)
          class << e
            attr_accessor :xtrace
          end
          e.xtrace = log_end(layer)
          raise
        end
      end
    end
  end
end
