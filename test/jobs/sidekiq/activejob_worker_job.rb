require "active_job/railtie"

Sidekiq.configure_server do |config|
  if ENV.key?('REDIS_PASSWORD')
    config.redis = { :password => ENV['REDIS_PASSWORD'] }
  end
end

ActiveJob::Base.queue_adapter = :sidekiq

class ActiveJobWorkerJob < ActiveJob::Base
  def perform(*_)
    []
  end
end

