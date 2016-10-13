# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

##
# Provides the methods necessary for method profiling.  Profiling
# results are sent to the TraceView dashboard.
#
# Example usage:
# class MyApp
#   include TraceViewMethodProfiling
#
#   def process_request()
#     # The hard work
#   end
#
#   # call syntax: profile_method <method>, <profile_name>
#   profile_method :process_request, 'request_processor'
# end
module TraceViewMethodProfiling
  def self.included(klass)
    klass.extend ClassMethods
  end

  module ClassMethods
    def profile_method_noop(*args)
      nil
    end

    def profile_method_real(method_name, profile_name, store_args = false, store_return = false, *_)
      begin
        # this only gets file and line where profiling is turned on, presumably
        # right after the function definition. ruby 1.9 and 2.0 has nice introspection (Method.source_location)
        # but its appears no such luck for ruby 1.8
        file = ''
        line = ''
        if RUBY_VERSION >= '1.9'
          info = instance_method(method_name).source_location
          unless info.nil?
            file = info[0].to_s
            line = info[1].to_s
          end
        else
          info = Kernel.caller[0].split(':')
          file = info.first.to_s
          line = info.last.to_s
        end

        # Safety:  Make sure there are no quotes or double quotes to break the class_eval
        file = file.gsub(/[\'\"]/, '')
        line = line.gsub(/[\'\"]/, '')

        # profiling via ruby-prof, is it possible to get return value of profiled code?
        code = "def _traceview_profiled_#{method_name}(*args, &block)
                  entry_kvs                  = {}
                  entry_kvs['Language']      = 'ruby'
                  entry_kvs['ProfileName']   = '#{TraceView::Util.prettify(profile_name)}'
                  entry_kvs['FunctionName']  = '#{TraceView::Util.prettify(method_name)}'
                  entry_kvs['File']          = '#{file}'
                  entry_kvs['LineNumber']    = '#{line}'
                  entry_kvs['Args']          = TraceView::API.pps(*args) if #{store_args}
                  entry_kvs.merge!(::TraceView::API.get_class_name(self))

                  TraceView::API.log(nil, 'profile_entry', entry_kvs)

                  ret = _traceview_orig_#{method_name}(*args, &block)

                  exit_kvs =  {}
                  exit_kvs['Language'] = 'ruby'
                  exit_kvs['ProfileName'] = '#{TraceView::Util.prettify(profile_name)}'
                  exit_kvs['ReturnValue'] = TraceView::API.pps(ret) if #{store_return}

                  TraceView::API.log(nil, 'profile_exit', exit_kvs)
                  ret
                end"
      rescue => e
        TraceView.logger.warn "[traceview/warn] profile_method: #{e.inspect}"
      end

      begin
        class_eval code, __FILE__, __LINE__
        alias_method "_traceview_orig_#{method_name}", method_name
        alias_method method_name, "_traceview_profiled_#{method_name}"
      rescue => e
        TraceView.logger.warn "[traceview/warn] Fatal error profiling method (#{method_name}): #{e.inspect}" if TraceView::Config[:verbose]
      end
    end

    # This allows this module to be included and called even if the gem is in
    # no-op mode (no base libraries).
    if TraceView.loaded
      alias :profile_method :profile_method_real
    else
      alias :profile_method :profile_method_noop
    end

  end
end
