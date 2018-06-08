require "active_job/railtie"

Sidekiq.configure_server do |config|
  config.redis = { :password => 'secret_pass' }
end

ActiveJob::Base.queue_adapter = :sidekiq

class ActiveJobWorkerJob < ActiveJob::Base
  def perform(*_)
    []
  end
end

