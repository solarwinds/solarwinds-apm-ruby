class MetalController < ActionController::Metal
  def index
    self.response_body = 'Hello Metal!'
  end

  include TraceViewMethodProfiling
  profile_method :index, 'metal-index'
end
