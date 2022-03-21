# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  ##
  # This module sends the duration of the call and
  # sets the transaction_name
  #
  class TransactionMetrics
    class << self

      ##
      # sends the duration of the call and
      # sets the transaction_name
      def metrics(env, settings)
        if settings.do_metrics
          req = ::Rack::Request.new(env)
          # TODO rails 3x is not supported anymore ...
          url = req.url   # saving it here because rails3.2 overrides it when there is a 500 error
          start = Time.now

          begin
            status, headers, response = yield

            SolarWindsAPM.transaction_name = send_metrics(env, req, url, start, status)
          rescue
            SolarWindsAPM.transaction_name = send_metrics(env, req, url, start, status || '500')
            raise
          end
        else
          status, headers, response = yield
          SolarWindsAPM.transaction_name = "#{domain(req)}#{transaction_name(env)}" if settings.do_sample
        end

        [status, headers, response]
      end

      private

      def send_metrics(env, req, url, start, status)
        name = transaction_name(env)

        status = status.to_i
        error = status.between?(500,599) ? 1 : 0
        duration =(1000 * 1000 * (Time.now - start)).round(0)
        method = req.request_method
        # SolarWindsAPM.logger.warn "%%% Sending metrics: #{name}, #{url}, #{status} %%%"
        SolarWindsAPM::Span.createHttpSpan(name, url, domain(req), duration, status, method, error) || ''
      end

      def domain(req)
        if SolarWindsAPM::Config['transaction_name']['prepend_domain']
          [80, 443].include?(req.port) ? req.host : "#{req.host}:#{req.port}"
        end
      end

      def transaction_name(env)
        return SolarWindsAPM.transaction_name  if SolarWindsAPM.transaction_name

        if env['appoptics_apm.controller'] && env['appoptics_apm.action']
          [env['appoptics_apm.controller'], env['appoptics_apm.action']].join('.')
        end
      end

    end
  end
end
