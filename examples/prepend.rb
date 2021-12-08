require 'solarwinds_apm'

module Measurements
  def request(*args, &block)
    req = args.first
    AppOpticsAPM::SDK.summary_metric("request_size", req.to_hash.to_s.size)
    resp = super
    AppOpticsAPM::SDK.summary_metric("response_size", resp.to_hash.to_s.size)
    return resp
  end
end

Net::HTTP.send(:prepend, :Measurements)
