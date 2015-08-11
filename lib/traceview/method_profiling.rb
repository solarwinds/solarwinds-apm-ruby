
module TraceView
  module MethodProfiling
    def profile_wrapper(method, report_kvs, report_arguments, report_result, *args, &block)
      TraceView::API.log(nil, 'profile_entry', report_kvs)

      begin
        report_kvs[:MethodName] = method
        report_kvs[:Arguments] = args if report_arguments
        rv = self.send(method, *args, &block)
        report_kvs[:ReturnValue] = rv if report_result
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
