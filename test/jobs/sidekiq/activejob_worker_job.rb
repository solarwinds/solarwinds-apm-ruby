require "active_job/railtie"

Sidekiq.configure_server do |config|
  config.redis ||= {}
  # if ENV.key?('REDIS_PASSWORD')
    config.redis << { :password => ENV['REDIS_PASSWORD'] | 'secret_pass'}
  # end
  if ENV.key?('REDIS_HOST')
    config.redis << { :url => "redis://#{ENV['REDIS_HOST']}:6379" }
  end
end

ActiveJob::Base.queue_adapter = :sidekiq

class ActiveJobWorkerJob < ActiveJob::Base
  def perform(*_)
    []
  end
end

