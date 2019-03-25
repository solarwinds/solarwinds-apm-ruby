# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  # This module sends the duration of the call and
  # sets the transaction_name
  #
  module TransactionMetrics
    class << self

      ##
      # sends the duration of the call and
      # sets the transaction_name
      def start_metrics(env, settings)
        if settings.do_metrics
          req = ::Rack::Request.new(env)
          url = req.url   # saving it here because rails3.2 overrides it when there is a 500 error
          start = Time.now

          begin
            status, headers, response = yield

            AppOpticsAPM.transaction_name = send_metrics(env, req, url, start, status)
          rescue
            AppOpticsAPM.transaction_name = send_metrics(env, req, url, start, status || '500')
            raise
          end
        else
          status, headers, response = yield
          AppOpticsAPM.transaction_name = "#{domain(req)}#{transaction_name(env)}" if settings.do_sample
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
        # AppOpticsAPM.logger.warn "%%% Sending metrics: #{name}, #{url}, #{status} %%%"
        AppOpticsAPM::Span.createHttpSpan(name, url, domain(req), duration, status, method, error) || ''
      end

      def domain(req)
        if AppOpticsAPM::Config['transaction_name']['prepend_domain']
          [80, 443].include?(req.port) ? req.host : "#{req.host}:#{req.port}"
        end
      end

      def transaction_name(env)
        return AppOpticsAPM.transaction_name  if AppOpticsAPM.transaction_name

        if env['appoptics_apm.controller'] && env['appoptics_apm.action']
          [env['appoptics_apm.controller'], env['appoptics_apm.action']].join('.')
        end
      end

    end
  end
end