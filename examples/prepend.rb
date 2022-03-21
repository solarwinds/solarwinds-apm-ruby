require 'solarwinds_apm'

module Measurements
  def request(*args, &block)
    req = args.first
    SolarWindsAPM::SDK.summary_metric("request_size", req.to_hash.to_s.size)
    resp = super
    SolarWindsAPM::SDK.summary_metric("response_size", resp.to_hash.to_s.size)
    return resp
  end
end

Net::HTTP.send(:prepend, :Measurements)
