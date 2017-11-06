class MetalController < ActionController::Metal
  def index
    self.response_body = 'Hello Metal!'
  end

  include AppOpticsMethodProfiling
  profile_method :index, 'metal-index'
end
