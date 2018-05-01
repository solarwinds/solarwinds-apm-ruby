# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  # This module exposes a nested configuration hash that can be used to
  # configure and/or modify the functionality of the appoptics_apm gem.
  #
  # Use AppOpticsAPM::Config.show to view the entire nested hash.
  #
  module Config
    @@config = {}

    @@instrumentation = [:action_controller, :action_controller_api, :action_view,
                         :active_record, :bunnyclient, :bunnyconsumer, :cassandra, :curb,
                         :dalli, :delayed_jobclient, :delayed_jobworker,
                         :em_http_request, :excon, :faraday, :grape,
                         :httpclient, :nethttp, :memcached, :mongo, :moped, :rack, :redis,
                         :resqueclient, :resqueworker, :rest_client,
                         :sequel, :sidekiqclient, :sidekiqworker, :typhoeus]

    # Subgrouping of instrumentation
    @@http_clients = [:curb, :excon, :em_http_request, :faraday, :httpclient, :nethttp, :rest_client, :typhoeus]

    ##
    # load_config_file
    #
    # There are 3 possible locations for the config file:
    # Rails default, ENV['APPOPTICS_APM_CONFIG_RUBY'], or the gem's default
    #
    # Hierarchie:
    # 1 - Rails default: config/initializers/appoptics_apm.rb
    #     (also loaded  by Rails, but we can't reliably determine if Rails is running)
    # 2 - ENV['APPOPTICS_APM_CONFIG_RUBY']
    # 3 - Gem default: <startup_dir>/appoptics_apm_config.rb
    #
    def self.load_config_file
      config_files = []

      # Check for the rails config file
      config_file = File.join(Dir.pwd, 'config/initializers/appoptics_apm.rb')
      config_files << config_file if File.exist?(config_file)

      # Check for file set by env variable
      if ENV.key?('APPOPTICS_APM_CONFIG_RUBY')
        if File.exist?(ENV['APPOPTICS_APM_CONFIG_RUBY']) && !File.directory?(ENV['APPOPTICS_APM_CONFIG_RUBY'])
          config_files << ENV['APPOPTICS_APM_CONFIG_RUBY']
        elsif File.exist?(File.join(ENV['APPOPTICS_APM_CONFIG_RUBY'], 'appoptics_apm_config.rb'))
          config_files << File.join(ENV['APPOPTICS_APM_CONFIG_RUBY'], 'appoptics_apm_config.rb')
        else
          $stderr.puts 'Could not find the configuration file set by the APPOPTICS_APM_CONFIG_RUBY environment variable:'
          $stderr.puts "#{ENV['APPOPTICS_APM_CONFIG_RUBY']}"
        end
      end

      # Check for default config file
      config_file = File.join(Dir.pwd, 'appoptics_apm_config.rb')
      config_files << config_file if File.exist?(config_file)

      return if config_files.empty?

      if config_files.size > 1
        $stderr.puts 'Found multiple configuration files, using the first one listed:'
        config_files.each { |path| $stderr.puts "  #{path}" }
      end
      load(config_files[0])
    end

    ##
    # print_config
    #
    # print configurations one per line
    # to create an output similar to the content of the config file
    #
    def self.print_config
      puts "# General configurations"
      non_instrumentation = @@config.keys - @@instrumentation
      non_instrumentation.each do |config|
        puts "AppOpticsAPM::Config[:#{config}] = #{@@config[config]}"
      end

      puts "\n# Instrumentation specific configurations"
      puts "# Enabled/Disabled Instrumentation"
      @@instrumentation.each do |config|
        puts "AppOpticsAPM::Config[:#{config}][:enabled] = #{@@config[config][:enabled]}"
      end

      puts "\n# Enabled/Disabled Backtrace Collection"
      @@instrumentation.each do |config|
        puts "AppOpticsAPM::Config[:#{config}][:collect_backtraces] = #{@@config[config][:collect_backtraces]}"
      end

      puts "\n# Logging of outgoing HTTP query args"
      @@instrumentation.each do |config|
        puts "AppOpticsAPM::Config[:#{config}][:log_args] = #{@@config[config][:log_args]}"
      end

      puts "\n# Bunny Controller and Action"
      puts "AppOpticsAPM::Config[:bunnyconsumer][:controller] = #{@@config[:bunnyconsumer][:controller].inspect}"
      puts "AppOpticsAPM::Config[:bunnyconsumer][:action] = #{@@config[:bunnyconsumer][:action].inspect}"
      nil
    end

    ##
    # initialize
    #
    # Initializer method to set everything up with a
    # default configuration.
    #
    # rubocop:disable Metrics/AbcSize
    def self.initialize(_data = {})
      # Setup default instrumentation values
      @@instrumentation.each do |k|
        @@config[k] = {}
        @@config[k][:enabled] = true
        @@config[k][:collect_backtraces] = false
        @@config[k][:log_args] = true
      end

      # Beta instrumentation disabled by default
      AppOpticsAPM::Config[:em_http_request][:enabled] = false

      # Set collect_backtraces defaults
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false
      AppOpticsAPM::Config[:action_controller_api][:collect_backtraces] = false
      AppOpticsAPM::Config[:active_record][:collect_backtraces] = true
      AppOpticsAPM::Config[:bunnyclient][:collect_backtraces] = false
      AppOpticsAPM::Config[:bunnyconsumer][:collect_backtraces] = false
      AppOpticsAPM::Config[:action_view][:collect_backtraces] = true
      AppOpticsAPM::Config[:cassandra][:collect_backtraces] = true
      AppOpticsAPM::Config[:curb][:collect_backtraces] = true
      AppOpticsAPM::Config[:dalli][:collect_backtraces] = false
      AppOpticsAPM::Config[:delayed_jobclient][:collect_backtraces] = false
      AppOpticsAPM::Config[:delayed_jobworker][:collect_backtraces] = false
      AppOpticsAPM::Config[:em_http_request][:collect_backtraces] = false
      AppOpticsAPM::Config[:excon][:collect_backtraces] = true
      AppOpticsAPM::Config[:faraday][:collect_backtraces] = false
      AppOpticsAPM::Config[:grape][:collect_backtraces] = true
      AppOpticsAPM::Config[:httpclient][:collect_backtraces] = true
      AppOpticsAPM::Config[:memcached][:collect_backtraces] = false
      AppOpticsAPM::Config[:mongo][:collect_backtraces] = true
      AppOpticsAPM::Config[:moped][:collect_backtraces] = true
      AppOpticsAPM::Config[:nethttp][:collect_backtraces] = true
      AppOpticsAPM::Config[:rack][:collect_backtraces] = false
      AppOpticsAPM::Config[:redis][:collect_backtraces] = false
      AppOpticsAPM::Config[:resqueclient][:collect_backtraces] = true
      AppOpticsAPM::Config[:resqueworker][:collect_backtraces] = false
      AppOpticsAPM::Config[:rest_client][:collect_backtraces] = false
      AppOpticsAPM::Config[:sequel][:collect_backtraces] = true
      AppOpticsAPM::Config[:sidekiqclient][:collect_backtraces] = false
      AppOpticsAPM::Config[:sidekiqworker][:collect_backtraces] = false
      AppOpticsAPM::Config[:typhoeus][:collect_backtraces] = false

      # Legacy Resque config support.  To be removed in a future version
      @@config[:resque] = {}

      # Setup an empty host blacklist (see: AppOpticsAPM::API::Util.blacklisted?)
      @@config[:blacklist] = []

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
      #   AppOpticsAPM::Config[:nethttp][:log_args] = false
      #   AppOpticsAPM::Config[:excon][:log_args] = false
      #   AppOpticsAPM::Config[:typhoeus][:log_args] = true
      #
      @@config[:include_url_query_params] = true

      # Logging of incoming HTTP query args
      #
      # This optionally disables the logging of incoming URL request
      # query args.
      #
      # This flag is global and currently only affects the Rack
      # instrumentation which reports incoming request URLs and
      # query args by default.
      @@config[:include_remote_url_params] = true

      # The AppOpticsAPM Ruby gem has the ability to sanitize query literals
      # from SQL statements.  By default this is enabled to
      # avoid collecting and reporting query literals to AppOpticsAPM.
      @@config[:sanitize_sql] = true

      # The regular expression used to sanitize SQL.
      @@config[:sanitize_sql_regexp] = '(\'[\s\S][^\']*\'|\d*\.\d+|\d+|NULL)'
      @@config[:sanitize_sql_opts]   = Regexp::IGNORECASE

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
      #   AppOpticsAPM::Config[:dnt_regexp] = "lobster$"
      #   AppOpticsAPM::Config[:dnt_opts]   = Regexp::IGNORECASE
      #
      # This will ignore all requests that end with the string lobster
      # regardless of case
      #
      # Requests with positive matches (non nil) will not be traced.
      # See lib/appoptics_apm/util.rb: AppOpticsAPM::Util.static_asset?
      #
      @@config[:dnt_regexp] = '\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|otf|eot|ttf|woff|woff2|svg|less)(\?.+){0,1}$'
      @@config[:dnt_opts]   = Regexp::IGNORECASE

      # In Rails, raised exceptions with rescue handlers via
      # <tt>rescue_from</tt> are not reported to the AppOptics
      # dashboard by default.  Setting this value to true will
      # report all raised exception regardless.
      #
      @@config[:report_rescued_errors] = false

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
      @@config[:bunnyconsumer][:controller] = :app_id
      @@config[:bunnyconsumer][:action] = :type

      @@config[:verbose] = ENV.key?('APPOPTICS_GEM_VERBOSE') && ENV['APPOPTICS_GEM_VERBOSE'] == 'true' ? true : false
    end
    # rubocop:enable Metrics/AbcSize

    def self.update!(data)
      data.each do |key, value|
        self[key] = value
      end
    end

    def self.merge!(data)
      update!(data)
    end

    def self.[](key)
      if key == :resque
        AppOpticsAPM.logger.warn '[appoptics_apm/warn] :resque config is deprecated.  It is now split into :resqueclient and :resqueworker.'
        AppOpticsAPM.logger.warn "[appoptics_apm/warn] Called from #{Kernel.caller[0]}"
      end

      @@config[key.to_sym]
    end

    ##
    # []=
    #
    # Config variable assignment method.  Here we validate and store the
    # assigned value(s) and trigger any secondary action needed.
    #
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    def self.[]=(key, value)
      @@config[key.to_sym] = value

      if key == :sampling_rate
        AppOpticsAPM.logger.warn '[appoptics_apm/config] sampling_rate is not a supported setting for AppOpticsAPM::Config.  ' \
                         'Please use :sample_rate.'

      elsif key == :sample_rate
        unless value.is_a?(Integer) || value.is_a?(Float)
          AppOpticsAPM.logger.warn "[appoptics_apm/config] :sample_rate must be a number between 0 and 1000000 (1m) " \
                                   "(provided: #{value}), corrected to 0"
          value = 0
        end

        # Validate :sample_rate value
        unless value.between?(0, 1e6)
          value_1 = value
          value = value_1 < 0 ? 0 : 1_000_000
          AppOpticsAPM.logger.warn "[appoptics_apm/config] :sample_rate must be between 0 and 1000000 (1m) " \
                                   "(provided: #{value_1}), corrected to #{value}"
        end

        # Assure value is an integer
        @@config[key.to_sym] = value.to_i
        AppOpticsAPM.set_sample_rate(value) if AppOpticsAPM.loaded

      elsif key == :action_blacklist
        AppOpticsAPM.logger.warn "[appoptics_apm/config] :action_blacklist has been deprecated and no longer functions."

      elsif key == :resque
        AppOpticsAPM.logger.warn "[appoptics_apm/config] :resque config is deprecated.  It is now split into :resqueclient and :resqueworker."
        AppOpticsAPM.logger.warn "[appoptics_apm/config] Called from #{Kernel.caller[0]}"

      elsif key == :include_url_query_params
        # Obey the global flag and update all of the per instrumentation
        # <tt>:log_args</tt> values.
        @@config[:rack][:log_args] = value

      elsif key == :include_remote_url_params
        # Obey the global flag and update all of the per instrumentation
        # <tt>:log_args</tt> values.
        @@http_clients.each do |i|
          @@config[i][:log_args] = value
        end

      # Update liboboe if updating :tracing_mode
      elsif key == :tracing_mode
        AppOpticsAPM.set_tracing_mode(value.to_sym) if AppOpticsAPM.loaded

        # Make sure that the mode is stored as a symbol
        @@config[key.to_sym] = value.to_sym
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

    def self.method_missing(sym, *args)
      class_var_name = "@@#{sym}"

      if sym.to_s =~ /(.+)=$/
        self[$1] = args.first
      else
        # Try part of the @@config hash first
        if @@config.key?(sym)
          self[sym]

        # Then try as a class variable
        elsif self.class_variable_defined?(class_var_name.to_sym)
          self.class_eval(class_var_name)

        # Congrats - You've won a brand new nil...
        else
          nil
        end
      end
    end
  end
end

AppOpticsAPM::Config.initialize
