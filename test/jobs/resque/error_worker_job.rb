# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

class ResqueErrorWorkerJob
  @queue = :critical

  def self.perform(*args)
    raise "This is a worker error yeah!"
  end
end
