
require_relative './job_initializer'

class ErrorWorkerJob
  include Sidekiq::Worker

  def perform(*args)
    raise "This is a worker error yeah!"
  end
end
