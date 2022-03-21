# Copyright (c) SolarWinds, LLC.
# All rights reserved

pattern = File.join(File.dirname(__FILE__), 'support', '*.rb')
Dir.glob(pattern) do |f|
  begin
    require f
  rescue => e
    SolarWindsAPM.logger.error "[appoptics_apm/loading] Error loading support file '#{f}' : #{e}"
    SolarWindsAPM.logger.debug "[appoptics_apm/loading] #{e.backtrace.first}"
  end
end
