
module TraceView
  module MethodProfiling
    def profile_wrapper(method, report_kvs, *args, &block)
      TraceView::API.log(nil, 'profile_entry', report_kvs)

      begin
        self.send(method, *args, &block)
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
