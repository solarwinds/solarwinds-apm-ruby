# AppOpticsAPM Initializer (for the appoptics_apm gem)
# https://www.appoptics.com/
#
# More information on instrumenting Ruby applications can be found here:
# https://docs.appoptics.com/kb/apm_tracing/ruby/
#
# The settings in this template file represent the defaults

if defined?(AppOpticsAPM::Config)

  #
  # Set APPOPTICS_SERVICE_KEY
  # This Setting will be overridden if APPOPTICS_SERVICE_KEY is set as an environment variable.
  # This is a required setting. If the service key is not set here it needs to be set as environment variable.
  #
  # The service key is a combination of the API token plus a service name.
  # E.g.: a4770c19-2503-439a-836e-a0ab5eb5b00f:rails_app
  #
  # AppOpticsAPM::Config[:service_key] = '11111111-1111-1111-1111-111111111111:the_service_name'

  #
  # Set APPOPTICS_HOSTNAME_ALIAS
  # This Setting will be overridden if APPOPTICS_HOSTNAME_ALIAS is set as an environment variable
  #
  # AppOpticsAPM::Config[:hostname_alias] = 'service_name'

  #
  # Set APPOPTICS_DEBUG_LEVEL
  # This Setting will be overridden if APPOPTICS_DEBUG_LEVEL is set as an environment variable
  #
  # It takes the following values:
  # 0 fatal, 1 error, 2 warning, 3 info (the default), 4 debug low, 5 debug medium, 6 debug high.
  #
  AppOpticsAPM::Config[:debug_level] = 3

  #
  # Set APPOPTICS_GEM_VERBOSE
  # This Setting will be overridden if APPOPTICS_GEM_VERBOSE is set as an environment variable
  #
  # On startup the components that are being instrumented will be reported if this is set to true.
  # If true and the log level is 4 or higher this may create extra debug log messages
  #
  AppOpticsAPM::Config[:verbose] = false

  #
  # Turn tracing on or off
  #
  # By default tracing is set to 'always', the other option is 'never'.
  # 'always' means that sampling will be done according to the current
  # sampling rate. 'never' means that there is no sampling.
  #
  AppOpticsAPM::Config[:tracing_mode] = :always

  #
  # Prepend domain to transaction name
  #
  # If this is set to `true` transaction names will be composed as `my.host.com/controller.action` instead of
  # `controller.action`. This configuration applies to all transaction names, whether deducted by the instrumentation
  # or implicitly set.
  #
  AppOpticsAPM::Config[:transaction_name][:prepend_domain] = false

  #
  # Sanitize SQL Statements
  #
  # The AppOpticsAPM Ruby client has the ability to sanitize query literals
  # from SQL statements.  By default this is enabled.  Disable to
  # collect and report query literals to AppOpticsAPM.
  #
  AppOpticsAPM::Config[:sanitize_sql] = true
  AppOpticsAPM::Config[:sanitize_sql_regexp] = '(\'[\s\S][^\']*\'|\d*\.\d+|\d+|NULL)'
  AppOpticsAPM::Config[:sanitize_sql_opts]   = Regexp::IGNORECASE

  #
  # Do Not Trace - DNT
  # 'dnt_regexp' and 'dnt_opts' allow you to configure specific URL patterns
  # to never be traced.  By default, this is set to common static file
  # extensions but you may want to customize this list for your needs.
  # Examples of such files may be images, javascript, pdfs, and text files.
  #
  # 'dnt_regexp' and 'dnt_opts' is passed to Regexp.new to create
  # a regular expression object.  That is then used to match against
  # the incoming request path.
  #
  # The path string originates from the rack layer and is retrieved
  # as follows:
  #
  #   req = ::Rack::Request.new(env)
  #   path = URI.unescape(req.path)
  #
  # Usage:
  #   AppOpticsAPM::Config[:dnt_regexp] = "lobster$"
  #   AppOpticsAPM::Config[:dnt_opts]   = Regexp::IGNORECASE
  #
  # This will ignore all requests that end with the string lobster
  # regardless of case
  #
  # Requests with positive matches (non nil) will not be traced.
  # See lib/appoptics_apm/util.rb: AppOpticsAPM::Util.static_asset?
  #
  AppOpticsAPM::Config[:dnt_regexp] = '\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|otf|eot|ttf|woff|woff2|svg|less)(\?.+){0,1}$'
  AppOpticsAPM::Config[:dnt_opts]   = Regexp::IGNORECASE

  #
  # Blacklist urls
  #
  # This configuration is used by outbound calls. If the call
  # goes to a blacklisted url then we won't add any
  # tracing information to the headers.
  #
  # The list has to an array of strings, even if only one url is blacklisted
  #
  # Example: AppOpticsAPM::Config[:blacklist] = ['google.com']
  #
  AppOpticsAPM::Config[:blacklist] = []
  #

  #
  # Rails Exception Logging
  #
  # In Rails, raised exceptions with rescue handlers via
  # <tt>rescue_from</tt> are not reported to the AppOptics
  # dashboard by default.  Setting this value to true will
  # report all raised exceptions regardless.
  #
  AppOpticsAPM::Config[:report_rescued_errors] = false
  #

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
  AppOpticsAPM::Config[:bunnyconsumer][:controller] = :app_id
  AppOpticsAPM::Config[:bunnyconsumer][:action] = :type
  #

  #
  # Enabling/Disabling Instrumentation
  #
  # If you're having trouble with one of the instrumentation libraries, they
  # can be individually disabled here by setting the :enabled
  # value to false:
  #
  AppOpticsAPM::Config[:action_controller][:enabled] = true
  AppOpticsAPM::Config[:action_controller_api][:enabled] = true
  AppOpticsAPM::Config[:action_view][:enabled] = true
  AppOpticsAPM::Config[:active_record][:enabled] = true
  AppOpticsAPM::Config[:bunnyclient][:enabled] = true
  AppOpticsAPM::Config[:bunnyconsumer][:enabled] = true
  AppOpticsAPM::Config[:cassandra][:enabled] = true
  AppOpticsAPM::Config[:curb][:enabled] = true
  AppOpticsAPM::Config[:dalli][:enabled] = true
  AppOpticsAPM::Config[:delayed_jobclient][:enabled] = true
  AppOpticsAPM::Config[:delayed_jobworker][:enabled] = true
  AppOpticsAPM::Config[:em_http_request][:enabled] = false
  AppOpticsAPM::Config[:excon][:enabled] = true
  AppOpticsAPM::Config[:faraday][:enabled] = true
  AppOpticsAPM::Config[:grape][:enabled] = true
  AppOpticsAPM::Config[:httpclient][:enabled] = true
  AppOpticsAPM::Config[:memcached][:enabled] = true
  AppOpticsAPM::Config[:mongo][:enabled] = true
  AppOpticsAPM::Config[:moped][:enabled] = true
  AppOpticsAPM::Config[:nethttp][:enabled] = true
  AppOpticsAPM::Config[:rack][:enabled] = true
  AppOpticsAPM::Config[:redis][:enabled] = true
  AppOpticsAPM::Config[:resqueclient][:enabled] = true
  AppOpticsAPM::Config[:resqueworker][:enabled] = true
  AppOpticsAPM::Config[:rest_client][:enabled] = true
  AppOpticsAPM::Config[:sequel][:enabled] = true
  AppOpticsAPM::Config[:sidekiqclient][:enabled] = true
  AppOpticsAPM::Config[:sidekiqworker][:enabled] = true
  AppOpticsAPM::Config[:typhoeus][:enabled] = true
  #

  #
  # Argument logging
  #
  # for http requests
  # Set to true to enable argument logging
  #
  AppOpticsAPM::Config[:bunnyconsumer][:log_args] = true
  AppOpticsAPM::Config[:curb][:log_args] = true
  AppOpticsAPM::Config[:excon][:log_args] = true
  AppOpticsAPM::Config[:httpclient][:log_args] = true
  AppOpticsAPM::Config[:mongo][:log_args] = true
  AppOpticsAPM::Config[:nethttp][:log_args] = true
  AppOpticsAPM::Config[:rack][:log_args] = true
  AppOpticsAPM::Config[:resqueclient][:log_args] = true
  AppOpticsAPM::Config[:resqueworker][:log_args] = true
  AppOpticsAPM::Config[:sidekiqclient][:log_args] = true
  AppOpticsAPM::Config[:sidekiqworker][:log_args] = true
  AppOpticsAPM::Config[:typhoeus][:log_args] = true
  #

  #
  # Enabling/Disabling Backtrace Collection
  #
  # Instrumentation can optionally collect backtraces as they collect
  # performance metrics.  Note that this has a negative impact on
  # performance but can be useful when trying to locate the source of
  # a certain call or operation.
  #
  AppOpticsAPM::Config[:action_controller][:collect_backtraces] = true
  AppOpticsAPM::Config[:action_controller_api][:collect_backtraces] = true
  AppOpticsAPM::Config[:action_view][:collect_backtraces] = true
  AppOpticsAPM::Config[:active_record][:collect_backtraces] = true
  AppOpticsAPM::Config[:bunnyclient][:collect_backtraces] = false
  AppOpticsAPM::Config[:bunnyconsumer][:collect_backtraces] = false
  AppOpticsAPM::Config[:cassandra][:collect_backtraces] = true
  AppOpticsAPM::Config[:curb][:collect_backtraces] = true
  AppOpticsAPM::Config[:dalli][:collect_backtraces] = false
  AppOpticsAPM::Config[:delayed_jobclient][:collect_backtraces] = false
  AppOpticsAPM::Config[:delayed_jobworker][:collect_backtraces] = false
  AppOpticsAPM::Config[:em_http_request][:collect_backtraces] = true
  AppOpticsAPM::Config[:excon][:collect_backtraces] = true
  AppOpticsAPM::Config[:faraday][:collect_backtraces] = false
  AppOpticsAPM::Config[:grape][:collect_backtraces] = true
  AppOpticsAPM::Config[:httpclient][:collect_backtraces] = true
  AppOpticsAPM::Config[:memcached][:collect_backtraces] = false
  AppOpticsAPM::Config[:mongo][:collect_backtraces] = true
  AppOpticsAPM::Config[:moped][:collect_backtraces] = true
  AppOpticsAPM::Config[:nethttp][:collect_backtraces] = true
  AppOpticsAPM::Config[:rack][:collect_backtraces] = true
  AppOpticsAPM::Config[:redis][:collect_backtraces] = false
  AppOpticsAPM::Config[:resqueclient][:collect_backtraces] = true
  AppOpticsAPM::Config[:resqueworker][:collect_backtraces] = true
  AppOpticsAPM::Config[:rest_client][:collect_backtraces] = true
  AppOpticsAPM::Config[:sequel][:collect_backtraces] = true
  AppOpticsAPM::Config[:sidekiqclient][:collect_backtraces] = false
  AppOpticsAPM::Config[:sidekiqworker][:collect_backtraces] = false
  AppOpticsAPM::Config[:typhoeus][:collect_backtraces] = false

end
