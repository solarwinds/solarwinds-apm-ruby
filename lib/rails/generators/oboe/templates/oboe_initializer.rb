if defined?(::Oboe::Config) 
  # Use these when there is no webserver to initiate tracing (apache/nginx)
  Oboe::Config[:tracing_mode] = "<%= @tracing_mode %>"
<% if ['through', 'never'].include?(@tracing_mode) %>
  # sample_rate is a value from 0 - 1m indicating the fraction of requests per million to trace
  # Oboe::Config[:sample_rate] = "<%= @sampling_rate %>"
<% else %>
  # sample_rate is a value from 0 - 1m indicating the fraction of requests per million to trace
  Oboe::Config[:sample_rate] = "<%= @sampling_rate %>"
<% end %>
  # Verbose output of instrumentation initialization
  # Oboe::Config[:verbose] = "<%= @verbose %>"
end
