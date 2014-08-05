module Faraday
  class Request::Timer < Faraday::Middleware

    Faraday::Request.register_middleware :timer => self

    def call(env)
      report_kvs = {}
      app = nil

      # Avoid cross host tracing for blacklisted domains
      blacklisted = Oboe::API.blacklisted?(addr_port)

      Oboe::API.trace('faraday') do
        
        # Add the X-Trace header to the outgoing request
        req['X-Trace'] = context unless blacklisted

        begin
          app = @app.call(env).on_complete do |environment|
            report_kvs['IsService'] = 1
            report_kvs['RemoteProtocol'] = @ssl ? ? 'HTTPS' : 'HTTP'
            report_kvs['RemoteHost'] = addr_port
            report_kvs['ServiceArg'] = req.path
            report_kvs['HTTPMethod'] = req.method
            report_kvs['Blacklisted'] = true if blacklisted
            report_kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:faraday][:collect_backtraces]
          end
          
          # Re-attach net::http edge unless blacklisted and is a valid X-Trace ID
          unless blacklisted
            xtrace = resp.get_fields('X-Trace')
            xtrace = xtrace[0] if xtrace and xtrace.is_a?(Array)

            if Oboe::XTrace.valid?(xtrace) and Oboe.tracing?

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == Oboe::XTrace.task_id(xtrace)
                Oboe::Context.fromString(xtrace)
              else
                Oboe.logger.debug "Mismatched returned X-Trace ID : #{xtrace}"
              end
            end
          end
        ensure 
          # Log the info event with the KVs in report_kvs
          Oboe::API.log('faraday', 'info', report_kvs)
        end
      end

      app
    end
  end
end
