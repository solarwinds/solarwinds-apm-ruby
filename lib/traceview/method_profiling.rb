
module TraceView
  module MethodProfiling
    def profile_wrapper(method, report_kvs, opts, *args, &block)
      report_kvs[:Backtrace] = TraceView::API.backtrace if opts[:backtrace]
      report_kvs[:Arguments] = args if opts[:arguments]

      TraceView::API.log(nil, 'profile_entry', report_kvs)

      begin
        rv = self.send(method, *args, &block)
        report_kvs[:ReturnValue] = rv if opts[:result]
        rv
      rescue => e
        TraceView::API.log_exception(nil, e)
        raise
      ensure
        report_kvs.delete(:Backtrace)
        TraceView::API.log(nil, 'profile_exit', report_kvs)
      end
    end
  end
end
