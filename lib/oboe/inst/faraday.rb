module Faraday
  class Request::TraceView < Faraday::Middleware

    Faraday::Request.register_middleware :traceview => self

    def call(env)
      report_kvs = {}
      app = nil

      context = Oboe::Context.toString()
      task_id = Oboe::XTrace.task_id(context)

      # Avoid cross host tracing for blacklisted domains
      blacklisted = Oboe::API.blacklisted?(env.url.to_s)

      Oboe::API.trace('faraday') do

        # Add the X-Trace header to the outgoing request
        env.request_headers['X-Trace'] = context unless blacklisted

        report_kvs['IsService'] = 1
        report_kvs['RemoteProtocol'] = (env[:url].scheme == 'https') ? 'HTTPS' : 'HTTP'
        report_kvs['RemoteHost'] = env[:url].port
        report_kvs['ServiceArg'] = env[:url].path
        report_kvs['HTTPMethod'] = env.method
        report_kvs['Blacklisted'] = true if blacklisted
        report_kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:faraday][:collect_backtraces]

        app = @app.call(env)

        # FIXME: We don't re-attach the X-Trace edge here because it has to be done
        # on the layer that is making the actual http request.  If using the net::http layer
        # it has to be done there.  We need a method to detect the adapter being used and
        # then act off of that.
        #
        # Re-attach net::http edge unless blacklisted and is a valid X-Trace ID
        #unless blacklisted
        #
        #  xtrace = env.response_headers['X-Trace']
        #
        #  if Oboe::XTrace.valid?(xtrace) and Oboe.tracing?
        #
        #    # Assure that we received back a valid X-Trace with the same task_id
        #    if task_id == Oboe::XTrace.task_id(xtrace)
        #      Oboe::Context.fromString(xtrace)
        #    else
        #      Oboe.logger.debug "Mismatched returned X-Trace ID : #{xtrace}"
        #    end
        #  end
        #end

        # Log the info event with the KVs in report_kvs
        Oboe::API.log('faraday', 'info', report_kvs)
      end

      app
    end # Oboe::API.start_trace
  end
end
