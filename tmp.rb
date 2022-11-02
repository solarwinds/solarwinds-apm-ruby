require 'redis'
require 'bson'
require 'solarwinds_apm'

def clear_all_traces
  if SolarWindsAPM.loaded && ENV['SW_APM_REPORTER'] == 'file'
    SolarWindsAPM::Reporter.clear_all_traces
    # SolarWindsAPM.trace_context = nil
    sleep 1 # it seems like the docker file system needs a bit of time to clear the file
  end
end

##
# get_all_traces
#
# Retrieves all traces written to the trace file
#
def get_all_traces
  if SolarWindsAPM.loaded && ENV['SW_APM_REPORTER'] == 'file'
    sleep 1
    SolarWindsAPM::Reporter.get_all_traces
  else
    []
  end
end

@redis ||= Redis.new(:host => ENV['REDIS_HOST'] || ENV['REDIS_SERVER'] || '127.0.0.1',
                     :password => ENV['REDIS_PASSWORD'] || 'secret_pass')

@redis_version ||= @redis.info["redis_version"]

# These are standard entry/exit KVs that are passed up with all moped operations
@entry_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'entry' }
@exit_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'exit' }
@exists_returns_integer = Redis.exists_returns_integer if defined? Redis.exists_returns_integer

clear_all_traces