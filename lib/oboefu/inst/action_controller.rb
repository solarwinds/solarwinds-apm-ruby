if defined?(ActionController::Base)
  ActionController::Base.class_eval do
    alias :old_perform_action :perform_action
    alias :old_rescue_action :rescue_action

    def perform_action(*arguments)
      header = @_request.headers['X-Trace']
      opts = @_request.path_parameters

      result, header = Oboe::Inst.trace_start_layer_block('rails', header, opts) do
        old_perform_action(*arguments)
      end

      @_response.headers['X-Trace'] = header if header
      result
    end

    def rescue_action(exn)
      Oboe::Inst.log_exception('rails', exn)
      old_rescue_action(exn)
    end
  end
end
