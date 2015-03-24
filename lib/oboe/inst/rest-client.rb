module Oboe
  module Inst
    module RestClientRequest
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :execute, ::RestClient::Request)
      end

      def execute_with_oboe & block
        # If we're not tracing or if rest-client is doing
        # nested loops (following redirects), then just
        # do a fast return.
        if !Oboe.tracing? || Oboe.tracing_layer?("rest-client")
          return execute_without_oboe(&block)
        end

        Oboe::API.log_entry('rest-client')

        blacklisted = Oboe::API.blacklisted?(@url)
        context = Oboe::Context.toString
        task_id = Oboe::XTrace.task_id(context)

        # Avoid cross host tracing for blacklisted domains
        # Conditionally add the X-Trace header to the outgoing request
        @headers['X-Trace'] = context unless blacklisted

        result = execute_without_oboe(&block)

        kvs = {}
        kvs[:HTTPStatus] = result.code
        kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:rest_client][:collect_backtraces]

        begin
          uri = parse_url_with_auth(@url)

          kvs['IsService'] = 1
          kvs['RemoteProtocol'] = (uri.scheme == 'https') ? 'HTTPS' : 'HTTP'
          kvs['RemoteHost'] = uri.host
          kvs['RemotePort'] = uri.port
          kvs['ServiceArg'] = uri.request_uri
          kvs['HTTPMethod'] = @method.to_s.upcase
          kvs['Blacklisted'] = true if blacklisted
        rescue => e
          Oboe.logger.debug "[oboe/debug] Problem capturing rest-client KVs: #{e.message}"
          Oboe.logger.debug e.backtrace if e.respond_to?(:backtrace) && Oboe::Config[:verbose]
        end

        # Re-attach net::http edge unless it's blacklisted or if we don't have a
        # valid X-Trace header
        unless blacklisted
          xtrace = result.headers[:x_trace]

          if Oboe::XTrace.valid?(xtrace) && Oboe.tracing?

            # Assure that we received back a valid X-Trace with the same task_id
            if task_id == Oboe::XTrace.task_id(xtrace)
              Oboe::Context.fromString(xtrace)
            else
              Oboe.logger.debug "Mismatched returned X-Trace ID: #{xtrace}"
            end
          end
        end

        Oboe::API.log_exit('rest-client', kvs)
        result
      rescue => e
        Oboe::API.log_exception('rest-client', e)
        raise e
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
