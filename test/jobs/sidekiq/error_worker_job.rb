# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

class ErrorWorkerJob
  include Sidekiq::Worker

  def perform(*args)
    raise "**************** This is a worker error yeah! ****************"
  end
end
