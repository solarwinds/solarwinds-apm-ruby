# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'net/http'

if Oboe::Config[:nethttp][:enabled]

  Net::HTTP.class_eval do
    def request_with_oboe(*args, &block)
      # If we're not tracing, just do a fast return. Since
      # net/http.request calls itself, only trace
      # once the http session has been started.
      if !Oboe.tracing? || !started?
        return request_without_oboe(*args, &block)
      end

      # Avoid cross host tracing for blacklisted domains
      blacklisted = Oboe::API.blacklisted?(addr_port)

      Oboe::API.trace('net-http') do
        opts = {}
        context = Oboe::Context.toString()
        task_id = Oboe::XTrace.task_id(context)

        # Collect KVs to report in the info event
        if args.length && args[0]
          req = args[0]

          opts['IsService'] = 1
          opts['RemoteProtocol'] = use_ssl? ? 'HTTPS' : 'HTTP'
          opts['RemoteHost'] = addr_port

          # Conditionally log query params
          if Oboe::Config[:nethttp][:log_args]
            opts['ServiceArg'] = req.path
          else
            opts['ServiceArg'] = req.path.split('?').first
          end

          opts['HTTPMethod'] = req.method
          opts['Blacklisted'] = true if blacklisted
          opts['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:nethttp][:collect_backtraces]

          req['X-Trace'] = context unless blacklisted
        end

        begin
          # The actual net::http call
          resp = request_without_oboe(*args, &block)

          # Re-attach net::http edge unless blacklisted and is a valid X-Trace ID
          unless blacklisted
            xtrace = resp.get_fields('X-Trace')
            xtrace = xtrace[0] if xtrace && xtrace.is_a?(Array)

            if Oboe::XTrace.valid?(xtrace)

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == Oboe::XTrace.task_id(xtrace)
                Oboe::Context.fromString(xtrace)
              else
                Oboe.logger.debug "Mismatched returned X-Trace ID : #{xtrace}"
              end
            end
          end

          opts['HTTPStatus'] = resp.code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? resp.code.to_i) && resp.header["Location"]
            opts["Location"] = resp.header["Location"]
          end

          next resp
        ensure
          # Log the info event with the KVs in opts
          Oboe::API.log('net-http', 'info', opts)
        end
      end
    end

    alias request_without_oboe request
    alias request request_with_oboe

    Oboe.logger.info '[oboe/loading] Instrumenting net/http' if Oboe::Config[:verbose]
  end
end
