
module AppOptics
  module MethodProfiling
    def profile_wrapper(method, report_kvs, opts, *args, &block)
      report_kvs[:Backtrace] = AppOptics::API.backtrace(2) if opts[:backtrace]
      report_kvs[:Arguments] = args if opts[:arguments]

      # if this is a rails controller we want to set the transaction for the outbound metrics
      if defined?(request) && defined?(request.env)
        report_kvs['Controller'] = self.class.name
        report_kvs['Action'] = self.action_name
        request.env['appoptics.controller'] = report_kvs['Controller']
        request.env['appoptics.action'] = report_kvs['Action']
      end

      AppOptics::API.log(nil, :profile_entry, report_kvs)

      begin
        rv = self.send(method, *args, &block)
        report_kvs[:ReturnValue] = rv if opts[:result]
        rv
      rescue => e
        AppOptics::API.log_exception(nil, e)
        raise
      ensure
        report_kvs.delete(:Backtrace)
        report_kvs.delete(:Controller)
        report_kvs.delete(:Action)
        AppOptics::API.log(nil, :profile_exit, report_kvs)
      end
    end
  end
end
