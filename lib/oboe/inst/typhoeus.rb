require 'byebug'
module Oboe
  module Inst
    module TyphoeusRequestOps

      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :run, ::Typhoeus::Request::Operations)
      end

      def run_with_oboe
        Oboe::API.log_entry('typhoeus')

        response = run_without_oboe

        if response.code == 0
          Oboe::API.log('typhoeus', 'error', { :ErrorClass => response.return_code,
                                               :ErrorMsg => response.return_message })
        end

        kvs = {}
        kvs[:HTTPStatus] = response.code
        kvs['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:typhoeus][:collect_backtraces]

        blacklisted = Oboe::API.blacklisted?(url)
        context = Oboe::Context.toString
        task_id = Oboe::XTrace.task_id(context)

        # Avoid cross host tracing for blacklisted domains
        # Conditionally add the X-Trace header to the outgoing request
        response.headers['X-Trace'] = context unless blacklisted

        uri = URI(response.effective_url)
        kvs['IsService'] = 1
        kvs['RemoteProtocol'] = uri.scheme
        kvs['RemoteHost'] = uri.host
        kvs['RemotePort'] = uri.port ? uri.port : 80
        kvs['ServiceArg'] = uri.path
        kvs['HTTPMethod'] = options[:method]
        kvs['Blacklisted'] = true if blacklisted

        # Re-attach net::http edge unless it's blacklisted or if we don't have a
        # valid X-Trace header
        unless blacklisted
          xtrace = response.headers['X-Trace']

          if Oboe::XTrace.valid?(xtrace) && Oboe.tracing?

            # Assure that we received back a valid X-Trace with the same task_id
            if task_id == Oboe::XTrace.task_id(xtrace)
              Oboe::Context.fromString(xtrace)
            else
              Oboe.logger.debug "Mismatched returned X-Trace ID: #{xtrace}"
            end
          end
        end

        Oboe::API.log('typhoeus', 'info', kvs)
        response
      rescue => e
        Oboe::API.log_exception('typhoeus', e)
        raise e
      ensure
        Oboe::API.log_exit('typhoeus')
      end
    end
  end
end

if Oboe::Config[:typhoeus][:enabled]
  if defined?(::Typhoeus)
    Oboe.logger.info '[oboe/loading] Instrumenting typhoeus' if Oboe::Config[:verbose]
    ::Oboe::Util.send_include(::Typhoeus::Request::Operations, ::Oboe::Inst::TyphoeusRequestOps)
  end
end
