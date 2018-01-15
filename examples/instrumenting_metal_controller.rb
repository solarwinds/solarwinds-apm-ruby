class MetalController < ActionController::Metal
  def index
    self.response_body = 'Hello Metal!'
  end

  include AppOpticsAPMMethodProfiling
  profile_method :index, 'metal-index'
end
