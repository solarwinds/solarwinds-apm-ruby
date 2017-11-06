# AppOptics Initializer (for the appoptics gem)
# https://appoptics.solarwinds.com/
#
# More information on instrumenting Ruby applications can be found here:
# http://docs.appoptics.solarwinds.com/Instrumentation/ruby.html#installing-ruby-instrumentation

if defined?(AppOptics::Config)
  # Verbose output of instrumentation initialization
  # AppOptics::Config[:verbose] = <%= @verbose %>

  # Logging of outgoing HTTP query args
  #
  # This optionally disables the logging of query args of outgoing
  # HTTP clients such as Net::HTTP, excon, typhoeus and others.
  #
  # This flag is global to all HTTP client instrumentation.
  #
  # To configure this on a per instrumentation basis, set this
  # option to true and instead disable the instrumenstation specific
  # option <tt>log_args</tt>:
  #
  #   AppOptics::Config[:nethttp][:log_args] = false
  #   AppOptics::Config[:excon][:log_args] = false
  #   AppOptics::Config[:typhoeus][:log_args] = true
  #
  AppOptics::Config[:include_url_query_params] = true

  # Logging of incoming HTTP query args
  #
  # This optionally disables the logging of incoming URL request
  # query args.
  #
  # This flag is global and currently only affects the Rack
  # instrumentation which reports incoming request URLs and
  # query args by default.
  AppOptics::Config[:include_remote_url_params] = true

  # The AppOptics Ruby client has the ability to sanitize query literals
  # from SQL statements.  By default this is disabled.  Enable to
  # avoid collecting and reporting query literals to AppOptics.
  # AppOptics::Config[:sanitize_sql] = false

  # Do Not Trace
  # These two values allow you to configure specific URL patterns to
  # never be traced.  By default, this is set to common static file
  # extensions but you may want to customize this list for your needs.
  #
  # dnt_regexp and dnt_opts is passed to Regexp.new to create
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
  #   AppOptics::Config[:dnt_regexp] = "lobster$"
  #   AppOptics::Config[:dnt_opts]   = Regexp::IGNORECASE
  #
  # This will ignore all requests that end with the string lobster
  # regardless of case
  #
  # Requests with positive matches (non nil) will not be traced.
  # See lib/appoptics/util.rb: AppOptics::Util.static_asset?
  #
  # AppOptics::Config[:dnt_regexp] = "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|ttf|woff|svg|less)$"
  # AppOptics::Config[:dnt_opts]   = Regexp::IGNORECASE

  #
  # Rails Exception Logging
  #
  # In Rails, raised exceptions with rescue handlers via
  # <tt>rescue_from</tt> are not reported to the AppOptics
  # dashboard by default.  Setting this value to true will
  # report all raised exception regardless.
  #
  # AppOptics::Config[:report_rescued_errors] = false
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
  # AppOptics::Config[:bunnyconsumer][:controller] = :app_id
  # AppOptics::Config[:bunnyconsumer][:action] = :type
  #

  #
  # Resque Options
  #
  # Set to true to disable Resque argument logging (Default: false)
  # AppOptics::Config[:resque][:log_args] = false
  #

  #
  # Enabling/Disabling Instrumentation
  #
  # If you're having trouble with one of the instrumentation libraries, they
  # can be individually disabled here by setting the :enabled
  # value to false:
  #
  # AppOptics::Config[:action_controller][:enabled] = true
  # AppOptics::Config[:action_view][:enabled] = true
  # AppOptics::Config[:active_record][:enabled] = true
  # AppOptics::Config[:bunnyclient][:enabled] = true
  # AppOptics::Config[:bunnyconsumer][:enabled] = true
  # AppOptics::Config[:cassandra][:enabled] = true
  # AppOptics::Config[:curb][:enabled] = true
  # AppOptics::Config[:dalli][:enabled] = true
  # AppOptics::Config[:delayed_jobclient][:enabled] = true
  # AppOptics::Config[:delayed_jobworker][:enabled] = true
  # AppOptics::Config[:excon][:enabled] = true
  # AppOptics::Config[:em_http_request][:enabled] = true
  # AppOptics::Config[:faraday][:enabled] = true
  # AppOptics::Config[:grape][:enabled] = true
  # AppOptics::Config[:httpclient][:enabled] = true
  # AppOptics::Config[:memcache][:enabled] = true
  # AppOptics::Config[:memcached][:enabled] = true
  # AppOptics::Config[:mongo][:enabled] = true
  # AppOptics::Config[:moped][:enabled] = true
  # AppOptics::Config[:nethttp][:enabled] = true
  # AppOptics::Config[:redis][:enabled] = true
  # AppOptics::Config[:resque][:enabled] = true
  # AppOptics::Config[:rest_client][:enabled] = true
  # AppOptics::Config[:sequel][:enabled] = true
  # AppOptics::Config[:sidekiqclient][:enabled] = true
  # AppOptics::Config[:sidekiqworker][:enabled] = true
  # AppOptics::Config[:typhoeus][:enabled] = true
  #

  #
  # Enabling/Disabling Backtrace Collection
  #
  # Instrumentation can optionally collect backtraces as they collect
  # performance metrics.  Note that this has a negative impact on
  # performance but can be useful when trying to locate the source of
  # a certain call or operation.
  #
  # AppOptics::Config[:action_controller][:collect_backtraces] = true
  # AppOptics::Config[:action_view][:collect_backtraces] = true
  # AppOptics::Config[:active_record][:collect_backtraces] = true
  # AppOptics::Config[:bunnyclient][:collect_backtraces] = true
  # AppOptics::Config[:bunnyconsumer][:collect_backtraces] = true
  # AppOptics::Config[:cassandra][:collect_backtraces] = true
  # AppOptics::Config[:curb][:collect_backtraces] = true
  # AppOptics::Config[:dalli][:collect_backtraces] = false
  # AppOptics::Config[:delayed_jobclient][:collect_backtraces] = false
  # AppOptics::Config[:delayed_jobworker][:collect_backtraces] = false
  # AppOptics::Config[:excon][:collect_backtraces] = false
  # AppOptics::Config[:em_http_request][:collect_backtraces] = true
  # AppOptics::Config[:faraday][:collect_backtraces] = false
  # AppOptics::Config[:grape][:collect_backtraces] = false
  # AppOptics::Config[:httpclient][:collect_backtraces] = false
  # AppOptics::Config[:memcache][:collect_backtraces] = false
  # AppOptics::Config[:memcached][:collect_backtraces] = false
  # AppOptics::Config[:mongo][:collect_backtraces] = true
  # AppOptics::Config[:moped][:collect_backtraces] = true
  # AppOptics::Config[:nethttp][:collect_backtraces] = true
  # AppOptics::Config[:redis][:collect_backtraces] = false
  # AppOptics::Config[:resque][:collect_backtraces] = true
  # AppOptics::Config[:rest_client][:collect_backtraces] = true
  # AppOptics::Config[:sequel][:collect_backtraces] = true
  # AppOptics::Config[:sidekiqclient][:collect_backtraces] = true
  # AppOptics::Config[:sidekiqworker][:collect_backtraces] = true
  # AppOptics::Config[:typhoeus][:collect_backtraces] = false
  #
end
