module Oboe
  module Inst
    module FaradayConnection
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :run_request, ::Faraday::Connection)
      end

      def run_request_with_oboe(method, url, body, headers)
        kvs = {}
        handle_service = !@builder.handlers.include?(Faraday::Adapter::NetHttp)

        Oboe::API.trace('faraday', kvs) do
          kvs['Middleware'] = @builder.handlers
          kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:faraday][:collect_backtraces]

          # Only send service KVs if we're not using the Net::HTTP adapter
          if handle_service
            blacklisted = Oboe::API.blacklisted?(@url_prefix.to_s)
            context = Oboe::Context.toString
            task_id = Oboe::XTrace.task_id(context)

            # Avoid cross host tracing for blacklisted domains
            # Conditionally add the X-Trace header to the outgoing request
            @headers['X-Trace'] = context unless blacklisted

            kvs['IsService'] = 1
            kvs['RemoteProtocol'] = (@url_prefix.scheme == 'https') ? 'HTTPS' : 'HTTP'
            kvs['RemoteHost'] = @url_prefix.host
            kvs['RemotePort'] = @url_prefix.port
            kvs['ServiceArg'] = url
            kvs['HTTPMethod'] = method
            kvs['Blacklisted'] = true if blacklisted
          end

          result = run_request_without_oboe(method, url, body, headers)

          # Re-attach net::http edge unless it's blacklisted or if we don't have a
          # valid X-Trace header
          if handle_service && !blacklisted
            xtrace = result.headers['X-Trace']

            if Oboe::XTrace.valid?(xtrace) && Oboe.tracing?

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == Oboe::XTrace.task_id(xtrace)
                Oboe::Context.fromString(xtrace)
              else
                Oboe.logger.debug "Mismatched returned X-Trace ID: #{xtrace}"
              end
            end
          end

          kvs['HTTPStatus'] = result.status
          result
        end
      ensure
        Oboe::API.log('faraday', 'info', kvs) if handle_service
      end
    end
  end
end

if Oboe::Config[:faraday][:enabled]
  if defined?(::Faraday)
    Oboe.logger.info '[oboe/loading] Instrumenting faraday'
    ::Oboe::Util.send_include(::Faraday::Connection, ::Oboe::Inst::FaradayConnection)
  end
end
