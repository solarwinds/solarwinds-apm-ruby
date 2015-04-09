module Oboe
  module Inst
    module RestClientRequest
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :execute, ::RestClient::Request)
      end

      ##
      # oboe_collect
      #
      # Used to collect up KVs to be reported
      # to the TraceView dashboard.
      #
      def oboe_collect
        kvs = {}
        uri = parse_url_with_auth(@url)

        kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:rest_client][:collect_backtraces]
        kvs['IsService'] = 1
        kvs['RemoteProtocol'] = (uri.scheme == 'https') ? 'HTTPS' : 'HTTP'
        kvs['RemoteHost'] = uri.host
        kvs['RemotePort'] = uri.port
        kvs['ServiceArg'] = uri.request_uri
        kvs['HTTPMethod'] = @method.to_s.upcase
        kvs
      rescue => e
        Oboe.logger.debug "[oboe/debug] Problem capturing rest-client KVs: #{e.message}"
        Oboe.logger.debug e.backtrace if e.respond_to?(:backtrace) && Oboe::Config[:verbose]
        return kvs
      end

      ##
      # execute_with_oboe
      #
      # The wrapper method for RestClient::Request.execute
      #
      def execute_with_oboe & block
        # If we're not tracing or if rest-client is doing
        # nested loops (following redirects), then just
        # do a fast return.
        if !Oboe.tracing? || Oboe.tracing_layer?("rest-client")
          return execute_without_oboe(&block)
        end

        begin
          Oboe::API.log_entry('rest-client')

          blacklisted = Oboe::API.blacklisted?(@url)
          start_xtrace = Oboe::Context.toString

          # Try to grab KVs as early as possible in case an exception
          # is raised and we don't get a chance to.
          kvs = oboe_collect

          # Avoid cross host tracing for blacklisted domains
          # Conditionally add the X-Trace header to the outgoing request
          if blacklisted
            kvs['Blacklisted'] = true
          else
            @processed_headers['X-Trace'] = start_xtrace
          end

          # The core rest-client call
          result = execute_without_oboe(&block)

          kvs[:HTTPStatus] = result.code

          # Re-attach net::http edge unless it's blacklisted or if we don't have a
          # valid X-Trace header.  pickup_context will validate values.
          unless blacklisted
            Oboe::XTrace.continue_service_context(start_xtrace, result.headers[:x_trace])
          end
        rescue => e
          Oboe::API.log_exception('rest-client', e)
          raise e
        ensure
          Oboe::API.log_exit('rest-client', kvs)
        end
        result
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
