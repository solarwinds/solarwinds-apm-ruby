# frozen_string_literal: true

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

# SolarWindsAPM Initializer (for the solarwinds_apm gem)
# https://www.appoptics.com/
#
# More information on instrumenting Ruby applications can be found here:
# https://docs.appoptics.com/kb/apm_tracing/ruby/
#
# The settings in this template file represent the defaults

if defined?(SolarWindsAPM::Config)

  # :service_key, :hostname_alias, :http_proxy, and :debug_level
  # are startup settings and can't be changed afterwards.

  #
  # Set SW_APM_SERVICE_KEY
  # This setting will be overridden if SW_APM_SERVICE_KEY is set as an environment variable.
  # This is a required setting. If the service key is not set here it needs to be set as environment variable.
  #
  # The service key is a combination of the API token plus a service name.
  # E.g.: 0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service
  #
  # SolarWindsAPM::Config[:service_key] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'

  #
  # Set SW_APM_HOSTNAME_ALIAS
  # This setting will be overridden if SW_APM_HOSTNAME_ALIAS is set as an environment variable
  #
  # SolarWindsAPM::Config[:hostname_alias] = 'alias_name'

  #
  # Set Proxy for SolarWinds   # This setting will be overridden if SW_APM_PROXY is set as an environment variable.
  #
  # Please configure http_proxy if a proxy needs to be used to communicate with
  # the SolarWinds backend.
  # The format should either be http://<proxyHost>:<proxyPort> for a proxy
  # server that does not require authentication, or
  # http://<username>:<password>@<proxyHost>:<proxyPort> for a proxy server that
  # requires basic authentication.
  #
  # Note that while HTTP is the only type of connection supported, the traffic
  # to SolarWinds is still encrypted using SSL/TLS.
  #
  # It is recommended to configure the proxy in this file or as SW_APM_PROXY
  # environment variable. However, the agent's underlying network library will
  # use a system-wide proxy defined in the environment variables grpc_proxy,
  # https_proxy or http_proxy if no SolarWindsAPM-specific configuration is set.
  # Please refer to gRPC environment variables for more information.
  #
  # SolarWindsAPM::Config[:http_proxy] = http://<proxyHost>:<proxyPort>

  #
  # Set SW_APM_DEBUG_LEVEL
  # This setting will be overridden if SW_APM_DEBUG_LEVEL is set as an environment variable.
  #
  # It sets the log level and takes the following values:
  # -1 disabled, 0 fatal, 1 error, 2 warning, 3 info (the default), 4 debug low, 5 debug medium, 6 debug high.
  # Values out of range (< -1 or > 6) are ignored and the log level is set to the default (info).
  #
  SolarWindsAPM::Config[:debug_level] = 3

  #
  # :debug_level will be used in the c-extension of the gem and also mapped to the
  # Ruby logger as DISABLED, FATAL, ERROR, WARN, INFO, or DEBUG
  # The Ruby logger can afterwards be changed to a different level, e.g:
  # SolarWindsAPM.logger.level = Logger::INFO

  #
  # Set SW_APM_GEM_VERBOSE
  # This setting will be overridden if SW_APM_GEM_VERBOSE is set as an environment variable
  #
  # On startup the components that are being instrumented will be reported if this is set to true.
  # If true and the log level is 4 or higher this may create extra debug log messages
  #
  SolarWindsAPM::Config[:verbose] = false

  #
  # Turn code profiling on or off
  #
  # By default profiling is set to :disabled, the other option is :enabled.
  # :enabled means that any traced code will also be profiled to get deeper insight
  # into the methods called during a trace.
  # Profiling in the solarwinds_apm gem is based on the low-overhead, sampling
  # profiler implemented in stackprof.
  #
  SolarWindsAPM::Config[:profiling] = :disabled

  #
  # Set the profiling interval (in milliseconds)
  #
  # The default is 10 milliseconds, which means that the method call stack is
  # recorded every 10 milliseconds. Shorter intervals may give better insight,
  # but will incur more overhead.
  # Minimum: 1, Maximum: 100
  #
  SolarWindsAPM::Config[:profiling_interval] = 10

  #
  # Turn Tracing on or off
  #
  # By default tracing is set to :enabled, the other option is :disabled.
  # :enabled means that sampling will be done according to the current
  # sampling rate and metrics are reported.
  # :disabled means that there is no sampling and metrics are not reported.
  #
  # The values :always and :never are deprecated
  #
  SolarWindsAPM::Config[:tracing_mode] = :enabled

  #
  # Turn Trigger Tracing on or off
  #
  # By default trigger tracing is :enabled, the other option is :disabled.
  # It allows to use the X-Trace-Options header to force a request to be
  # traced (within rate limits set for trigger tracing)
  #
  SolarWindsAPM::Config[:trigger_tracing_mode] = :enabled

  #
  # Trace Context in Logs
  #
  # Configure if and when the Trace ID should be included in application logs.
  # Common Ruby and Rails loggers are auto-instrumented, so that they can include
  # the current Trace ID in log messages.
  #
  # The added string will look like:
  # "trace_id=7435a9fe510ae4533414d425dadf4e18 span_id=49e60702469db05f trace_flags=00"
  #
  # The following options are available:
  # :never    (default)
  # :sampled  only include the Trace ID of sampled requests
  # :traced   include the Trace ID for all traced requests
  # :always   always add a Trace ID, it will be
  #           "trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00"
  #           when there is no tracing context.
  #
  SolarWindsAPM::Config[:log_traceId] = :never

  #
  # Trace Context in Queries (sql only)
  #
  # Configure to add the trace context to sql queries so that queries and
  # transactions can be linked in the SolarWinds dashboard
  #
  # This option can add a small overhead for queries that use prepared
  # statements as those statements will be recompiled whenever the trace context
  # is added (about 10% of the requests)
  #
  # the options are:
  # - true   (default) no trace context is added
  # - false  the tracecontext is added as comment to the start of the query, e.g:
  #          "/*traceparent='00-268748089f148899e29fc5711aca7760-7c6c704dcbba6682-01'*/SELECT `widgets`.* FROM `widgets` WHERE ..."
  #
  SolarWindsAPM::Config[:tag_sql] = false

  #
  # Sanitize SQL Statements
  #
  # The SolarWindsAPM Ruby client has the ability to sanitize query literals
  # from SQL statements.  By default this is enabled.  Disable to
  # collect and report query literals to SolarWindsAPM.
  #
  SolarWindsAPM::Config[:sanitize_sql] = true
  SolarWindsAPM::Config[:sanitize_sql_regexp] = '(\'[^\']*\'|\d*\.\d+|\d+|NULL)'
  SolarWindsAPM::Config[:sanitize_sql_opts]   = Regexp::IGNORECASE

  #
  # Prepend Domain to Transaction Name
  #
  # If this is set to `true` transaction names will be composed as
  # `my.host.com/controller.action` instead of `controller.action`.
  # This configuration applies to all transaction names, whether deduced by the
  # instrumentation or implicitly set.
  #
  SolarWindsAPM::Config[:transaction_name][:prepend_domain] = false

  #
  # Do Not Trace - DNT
  #
  # DEPRECATED
  # Please comment out if no filtering is desired, e.g. your static
  # assets are served by the web server and not the application
  #
  # This configuration allows creating a regexp for paths that should be excluded
  # from solarwinds_apm processing.
  #
  # For example:
  # - static assets that aren't served by the web server, or
  # - healthcheck endpoints that respond to a heart beat.
  #
  # :dnt_regexp is the regular expression that is applied to the incoming path
  # to determine whether the request should be measured and traced or not.
  #
  # :dnt_opts can be commented out, nil, or Regexp::IGNORECASE
  #
  # The matching happens before routes are applied.
  # The path originates from the rack layer and is retrieved as follows:
  #   req = ::Rack::Request.new(env)
  #   path = URI.unescape(req.path)
  #
  SolarWindsAPM::Config[:dnt_regexp] = '\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|otf|eot|ttf|woff|woff2|svg|less)(\?.+){0,1}$'
  SolarWindsAPM::Config[:dnt_opts] = Regexp::IGNORECASE

  #
  # GraphQL
  #
  # Enable tracing for GraphQL.
  # (true | false, default: true)
  SolarWindsAPM::Config[:graphql][:enabled] = true
  # Replace query arguments with a '?' when sent with a trace.
  # (true | false, default: true)
  SolarWindsAPM::Config[:graphql][:sanitize] = true
  # Remove comments from queries when sent with a trace.
  # (true | false, default: true)
  SolarWindsAPM::Config[:graphql][:remove_comments] = true
  # Create a transaction name by combining
  # "query" or "mutation" with the first word of the query.
  # This overwrites the default transaction name, which is a combination of
  # controller + action and would be the same for all graphql queries.
  # (true | false, default: true)
  SolarWindsAPM::Config[:graphql][:transaction_name] = true

  #
  # Rack::Cache
  #
  # Create a transaction name like `rack-cache.<cache-store>`,
  # e.g. `rack-cache.memcached`
  # This can reduce the number of transaction names, when many requests are
  # served directly from the cache without hitting a controller action.
  # When set to `false` the path will be used for the transaction name.
  #
  SolarWindsAPM::Config[:rack_cache] = { transaction_name: true }

  #
  # Transaction Settings
  #
  # Use this configuration to add exceptions to the global tracing mode and
  # disable/enable metrics and traces for certain transactions.
  #
  # Currently allowed hash keys:
  # :url to apply listed filters to urls.
  #      The matching of settings to urls happens before routes are applied.
  #      The url is extracted from the env argument passed to rack: `env['PATH_INFO']`
  #
  # and the hashes within the :url list either:
  #   :extensions  takes an array of strings for filtering (not regular expressions!)
  #   :tracing     defaults to :disabled, can be set to :enabled to override
  #              the global :disabled setting
  # or:
  #   :regexp      is a regular expression that is applied to the incoming path
  #   :opts        (optional) nil(default) or Regexp::IGNORECASE (options for regexp)
  #   :tracing     defaults to :disabled, can be set to :enabled to override
  #              the global :disabled setting
  #
  # Be careful not to add too many :regexp configurations as they will slow
  # down execution.
  #
  SolarWindsAPM::Config[:transaction_settings] = {
    url: [
      #   {
      #     extensions: %w['long_job'],
      #     tracing: :disabled
      #   },
      #   {
      #     regexp: '^.*\/long_job\/.*$',
      #     opts: Regexp::IGNORECASE,
      #     tracing: :disabled
      #   },
      #   {
      #     regexp: /batch/,
      #   }
    ]
  }

  #
  # Rails Exception Logging
  #
  # In Rails, raised exceptions with rescue handlers via
  # <tt>rescue_from</tt> are not reported to the SolarWinds   # dashboard by default.  Setting this value to true will
  # report all raised exceptions regardless.
  #
  SolarWindsAPM::Config[:report_rescued_errors] = false

  #
  # EC2 Metadata Fetching Timeout
  #
  # The timeout can be in the range 0 - 3000 (milliseconds)
  # Setting to 0 milliseconds effectively disables fetching from
  # the metadata URL (not waiting), and should only be used if
  # not running on EC2 / Openstack to minimize agent start up time.
  #
  SolarWindsAPM::Config[:ec2_metadata_timeout] = 1000

  #############################################
  ## SETTINGS FOR INDIVIDUAL GEMS/FRAMEWORKS ##
  #############################################

  #
  # Bunny Controller and Action
  #
  # The bunny (Rabbitmq) instrumentation can optionally report
  # Controller and Action values to allow filtering of bunny
  # message handling in # the UI.  Use of Controller and Action
  # for filters is temporary until the UI is updated with
  # additional filters.
  #
  # These values identify which properties of
  # Bunny::MessageProperties to report as Controller
  # and Action.  The defaults are to report :app_id (as
  # Controller) and :type (as Action).  If these values
  # are not specified in the publish, then nothing
  # will be reported here.
  #
  SolarWindsAPM::Config[:bunnyconsumer][:controller] = :app_id
  SolarWindsAPM::Config[:bunnyconsumer][:action] = :type

  #
  # Enabling/Disabling Instrumentation
  #
  # If you're having trouble with one of the instrumentation libraries, they
  # can be individually disabled here by setting the :enabled
  # value to false.
  #
  # :enabled settings are read on startup and can't be changed afterwards
  #
  SolarWindsAPM::Config[:action_controller][:enabled] = true
  SolarWindsAPM::Config[:action_controller_api][:enabled] = true
  SolarWindsAPM::Config[:action_view][:enabled] = true
  SolarWindsAPM::Config[:active_record][:enabled] = true
  SolarWindsAPM::Config[:bunnyclient][:enabled] = true
  SolarWindsAPM::Config[:bunnyconsumer][:enabled] = true
  SolarWindsAPM::Config[:cassandra][:enabled] = true
  SolarWindsAPM::Config[:curb][:enabled] = true
  SolarWindsAPM::Config[:dalli][:enabled] = true
  SolarWindsAPM::Config[:delayed_jobclient][:enabled] = true
  SolarWindsAPM::Config[:delayed_jobworker][:enabled] = true
  # SolarWindsAPM::Config[:em_http_request][:enabled] = false # not supported anymore
  SolarWindsAPM::Config[:excon][:enabled] = true
  SolarWindsAPM::Config[:faraday][:enabled] = true
  SolarWindsAPM::Config[:grpc_client][:enabled] = true
  SolarWindsAPM::Config[:grpc_server][:enabled] = true
  SolarWindsAPM::Config[:grape][:enabled] = true
  SolarWindsAPM::Config[:httpclient][:enabled] = true
  SolarWindsAPM::Config[:memcached][:enabled] = true
  SolarWindsAPM::Config[:mongo][:enabled] = true
  SolarWindsAPM::Config[:moped][:enabled] = true
  SolarWindsAPM::Config[:nethttp][:enabled] = true
  SolarWindsAPM::Config[:padrino][:enabled] = true
  SolarWindsAPM::Config[:rack][:enabled] = true
  SolarWindsAPM::Config[:redis][:enabled] = true
  SolarWindsAPM::Config[:resqueclient][:enabled] = true
  SolarWindsAPM::Config[:resqueworker][:enabled] = true
  SolarWindsAPM::Config[:rest_client][:enabled] = true
  SolarWindsAPM::Config[:sequel][:enabled] = true
  SolarWindsAPM::Config[:sidekiqclient][:enabled] = true
  SolarWindsAPM::Config[:sidekiqworker][:enabled] = true
  SolarWindsAPM::Config[:sinatra][:enabled] = true
  SolarWindsAPM::Config[:typhoeus][:enabled] = true

  #
  # Argument logging
  #
  #
  # For http requests:
  # By default the query string parameters are included in the URLs reported.
  # Set :log_args to false and instrumentation will stop collecting
  # and reporting query arguments from URLs.
  #
  SolarWindsAPM::Config[:bunnyconsumer][:log_args] = true
  SolarWindsAPM::Config[:curb][:log_args] = true
  SolarWindsAPM::Config[:excon][:log_args] = true
  SolarWindsAPM::Config[:httpclient][:log_args] = true
  SolarWindsAPM::Config[:mongo][:log_args] = true
  SolarWindsAPM::Config[:nethttp][:log_args] = true
  SolarWindsAPM::Config[:rack][:log_args] = true
  SolarWindsAPM::Config[:resqueclient][:log_args] = true
  SolarWindsAPM::Config[:resqueworker][:log_args] = true
  SolarWindsAPM::Config[:sidekiqclient][:log_args] = true
  SolarWindsAPM::Config[:sidekiqworker][:log_args] = true
  SolarWindsAPM::Config[:typhoeus][:log_args] = true

  #
  # Enabling/Disabling Backtrace Collection
  #
  # Instrumentation can optionally collect backtraces as they collect
  # performance metrics.  Note that this has a negative impact on
  # performance but can be useful when trying to locate the source of
  # a certain call or operation.
  #
  SolarWindsAPM::Config[:action_controller][:collect_backtraces] = true
  SolarWindsAPM::Config[:action_controller_api][:collect_backtraces] = true
  SolarWindsAPM::Config[:action_view][:collect_backtraces] = true
  SolarWindsAPM::Config[:active_record][:collect_backtraces] = true
  SolarWindsAPM::Config[:bunnyclient][:collect_backtraces] = false
  SolarWindsAPM::Config[:bunnyconsumer][:collect_backtraces] = false
  SolarWindsAPM::Config[:cassandra][:collect_backtraces] = true
  SolarWindsAPM::Config[:curb][:collect_backtraces] = true
  SolarWindsAPM::Config[:dalli][:collect_backtraces] = false
  SolarWindsAPM::Config[:delayed_jobclient][:collect_backtraces] = false
  SolarWindsAPM::Config[:delayed_jobworker][:collect_backtraces] = false
  # SolarWindsAPM::Config[:em_http_request][:collect_backtraces] = true # not supported anymore
  SolarWindsAPM::Config[:excon][:collect_backtraces] = true
  SolarWindsAPM::Config[:faraday][:collect_backtraces] = false
  SolarWindsAPM::Config[:grape][:collect_backtraces] = true
  SolarWindsAPM::Config[:grpc_client][:collect_backtraces] = false
  SolarWindsAPM::Config[:grpc_server][:collect_backtraces] = false
  SolarWindsAPM::Config[:httpclient][:collect_backtraces] = true
  SolarWindsAPM::Config[:memcached][:collect_backtraces] = false
  SolarWindsAPM::Config[:mongo][:collect_backtraces] = true
  SolarWindsAPM::Config[:moped][:collect_backtraces] = true
  SolarWindsAPM::Config[:nethttp][:collect_backtraces] = true
  SolarWindsAPM::Config[:padrino][:collect_backtraces] = true
  SolarWindsAPM::Config[:rack][:collect_backtraces] = true
  SolarWindsAPM::Config[:redis][:collect_backtraces] = false
  SolarWindsAPM::Config[:resqueclient][:collect_backtraces] = true
  SolarWindsAPM::Config[:resqueworker][:collect_backtraces] = true
  SolarWindsAPM::Config[:rest_client][:collect_backtraces] = true
  SolarWindsAPM::Config[:sequel][:collect_backtraces] = true
  SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces] = false
  SolarWindsAPM::Config[:sidekiqworker][:collect_backtraces] = false
  SolarWindsAPM::Config[:sinatra][:collect_backtraces] = true
  SolarWindsAPM::Config[:typhoeus][:collect_backtraces] = false

end
