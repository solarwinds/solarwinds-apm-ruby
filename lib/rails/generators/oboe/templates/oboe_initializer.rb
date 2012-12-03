if defined?(::Oboe::Config) 
  # When traces should be initiated for incoming requests. Valid options are 'always', 
  # 'through' (when the request is initiated with a tracing header from upstream) and 'never'. 
  # You must set this directive to 'always' in order to initiate tracing when there
  # is no front-end webserver initiating traces.
  Oboe::Config[:tracing_mode] = '<%= @tracing_mode %>'
<% if ['through', 'never'].include?(@tracing_mode) %>
  # sample_rate is a value from 0 - 1m indicating the fraction of requests per million to trace
  # Oboe::Config[:sample_rate] = <%= @sampling_rate %>
<% else %>
  # sample_rate is a value from 0 - 1m indicating the fraction of requests per million to trace
  Oboe::Config[:sample_rate] = <%= @sampling_rate %>
<% end %>
  # Verbose output of instrumentation initialization
  # Oboe::Config[:verbose] = <%= @verbose %>
end
