require 'byebug'

module Oboe
  module Inst
    module RestClientRequest
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :execute, ::RestClient::Request)
      end

      ##
      # execute_with_oboe
      #
      # The wrapper method for RestClient::Request.execute
      #
      def execute_with_oboe & block
        kvs = {}
        kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:rest_client][:collect_backtraces]
        Oboe::API.log_entry("rest-client", kvs)

        # The core rest-client call
        execute_without_oboe(&block)
      rescue => e
        Oboe::API.log_exception('rest-client', e)
        raise e
      ensure
        Oboe::API.log_exit("rest-client")
      end
    end
  end
end

if Oboe::Config[:rest_client][:enabled]
  if defined?(::RestClient)
    Oboe.logger.info '[oboe/loading] Instrumenting rest-client' if Oboe::Config[:verbose]
    ::Oboe::Util.send_include(::RestClient::Request, ::Oboe::Inst::RestClientRequest)
  end
end
