# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require_relative 'support/transaction_settings'

module SolarWindsAPM
  ##
  # This module exposes a nested configuration hash that can be used to
  # configure and/or modify the functionality of the appoptics_apm gem.
  #
  # Use SolarWindsAPM::Config.show to view the entire nested hash.
  #
  module Config
    @@config = {}

    @@instrumentation = [:action_controller, :action_controller_api, :action_view,
                         :active_record, :bunnyclient, :bunnyconsumer, :cassandra, :curb,
                         :dalli, :delayed_jobclient, :delayed_jobworker,
                         :excon, :faraday, :graphql, :grpc_client, :grpc_server, :grape,
                         :httpclient, :nethttp, :memcached, :mongo, :moped, :padrino, :rack, :redis,
                         :resqueclient, :resqueworker, :rest_client,
                         :sequel, :sidekiqclient, :sidekiqworker, :sinatra, :typhoeus]

    # ignore configs for instrumentations we don't have anymore
    # can't remove because the config may still be present in configs created
    # with previous gem versions
    @@ignore = [:em_http_request]

    # Subgrouping of instrumentation
    @@http_clients = [:curb, :excon,
                      # :em_http_request,
                      :faraday, :httpclient, :nethttp, :rest_client, :typhoeus]

    ##
    # load_config_file
    #
    # There are 3 possible locations for the config file:
    # Rails default, ENV['SW_AMP_APM_CONFIG_RUBY'], or the gem's default
    #
    # Hierarchie:
    # 1 - Rails default: config/initializers/appoptics_apm.rb
    #     (also loaded  by Rails, but we can't reliably determine if Rails is running)
    # 2 - ENV['SW_AMP_APM_CONFIG_RUBY']
    # 3 - Gem default: <startup_dir>/appoptics_apm_config.rb
    #
    def self.load_config_file
      config_files = []

      # Check for the rails config file
      config_file = File.join(Dir.pwd, 'config/initializers/appoptics_apm.rb')
      config_files << config_file if File.exist?(config_file)

      # Check for file set by env variable
      if ENV.key?('SW_AMP_APM_CONFIG_RUBY')
        if File.exist?(ENV['SW_AMP_APM_CONFIG_RUBY']) && !File.directory?(ENV['SW_AMP_APM_CONFIG_RUBY'])
          config_files << ENV['SW_AMP_APM_CONFIG_RUBY']
        elsif File.exist?(File.join(ENV['SW_AMP_APM_CONFIG_RUBY'], 'appoptics_apm_config.rb'))
          config_files << File.join(ENV['SW_AMP_APM_CONFIG_RUBY'], 'appoptics_apm_config.rb')
        else
          SolarWindsAPM.logger.warn "[appoptics_apm/config] Could not find the configuration file set by the SW_AMP_APM_CONFIG_RUBY environment variable:  #{ENV['SW_AMP_APM_CONFIG_RUBY']}"
        end
      end

      # Check for default config file
      config_file = File.join(Dir.pwd, 'appoptics_apm_config.rb')
      config_files << config_file if File.exist?(config_file)

      unless config_files.empty? # we use the defaults from the template if there are no config files
        if config_files.size > 1
          SolarWindsAPM.logger.warn [
                                     '[appoptics_apm/config] Multiple configuration files configured, using the first one listed: ',
                                     config_files.join(', ')
                                   ].join(' ')
        end
        load(config_files[0])
      end

      # sets SolarWindsAPM::Config[:debug_level], SolarWindsAPM.logger.level
      set_log_level

      # the verbose setting is only relevant for ruby, ENV['SW_AMP_GEM_VERBOSE'] overrides
      if ENV.key?('SW_AMP_GEM_VERBOSE')
        SolarWindsAPM::Config[:verbose] = ENV['SW_AMP_GEM_VERBOSE'].downcase == 'true'
      end
    end

    def self.set_log_level
      unless (-1..6).include?(SolarWindsAPM::Config[:debug_level])
        SolarWindsAPM::Config[:debug_level] = 3
      end

      # let's find and use the equivalent debug level for ruby
      debug_level = (ENV['SW_AMP_DEBUG_LEVEL'] || SolarWindsAPM::Config[:debug_level] || 3).to_i
      if debug_level < 0
        # there should be no logging if SW_AMP_DEBUG_LEVEL == -1
        # In Ruby level 5 is UNKNOWN and it can log, but level 6 is quiet
        SolarWindsAPM.logger.level = 6
      else
        SolarWindsAPM.logger.level = [4 - debug_level, 0].max
      end
      SolarWindsAPM::Config[:debug_level] = debug_level
    end

    ##
    # print_config
    #
    # print configurations one per line
    # to create an output similar to the content of the config file
    #
    def self.print_config
      SolarWindsAPM.logger.warn "# General configurations"
      non_instrumentation = @@config.keys - @@instrumentation
      non_instrumentation.each do |config|
        SolarWindsAPM.logger.warn "SolarWindsAPM::Config[:#{config}] = #{@@config[config]}"
      end

      SolarWindsAPM.logger.warn "\n# Instrumentation specific configurations"
      SolarWindsAPM.logger.warn "# Enabled/Disabled Instrumentation"
      @@instrumentation.each do |config|
        SolarWindsAPM.logger.warn "SolarWindsAPM::Config[:#{config}][:enabled] = #{@@config[config][:enabled]}"
      end

      SolarWindsAPM.logger.warn "\n# Enabled/Disabled Backtrace Collection"
      @@instrumentation.each do |config|
        SolarWindsAPM.logger.warn "SolarWindsAPM::Config[:#{config}][:collect_backtraces] = #{@@config[config][:collect_backtraces]}"
      end

      SolarWindsAPM.logger.warn "\n# Logging of outgoing HTTP query args"
      @@instrumentation.each do |config|
        SolarWindsAPM.logger.warn "SolarWindsAPM::Config[:#{config}][:log_args] = #{@@config[config][:log_args] || false}"
      end

      SolarWindsAPM.logger.warn "\n# Bunny Controller and Action"
      SolarWindsAPM.logger.warn "SolarWindsAPM::Config[:bunnyconsumer][:controller] = #{@@config[:bunnyconsumer][:controller].inspect}"
      SolarWindsAPM.logger.warn "SolarWindsAPM::Config[:bunnyconsumer][:action] = #{@@config[:bunnyconsumer][:action].inspect}"
      nil
    end

    ##
    # initialize
    #
    # Initializer method to set everything up with a default configuration.
    # The defaults are read from the template configuration file.
    #
    # rubocop:disable Metrics/AbcSize
    def self.initialize(_data = {})
      (@@instrumentation+@@ignore).each { |k| @@config[k] = {} }
      @@config[:transaction_name] = {}

      # Always load the template, it has all the keys and defaults defined,
      # no guarantee of completeness in the user's config file
      load(File.join(File.dirname(File.dirname(__FILE__)),
                    'rails/generators/appoptics_apm/templates/appoptics_apm_initializer.rb'))
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
        SolarWindsAPM.logger.warn '[appoptics_apm/warn] :resque config is deprecated.  It is now split into :resqueclient and :resqueworker.'
        SolarWindsAPM.logger.warn "[appoptics_apm/warn] Called from #{Kernel.caller[0]}"
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
      key = key.to_sym
      @@config[key] = value

      if key == :sampling_rate
        SolarWindsAPM.logger.warn '[appoptics_apm/config] sampling_rate is not a supported setting for SolarWindsAPM::Config.  ' \
                                 'Please use :sample_rate.'

      elsif key == :sample_rate
        unless value.is_a?(Integer) || value.is_a?(Float)
          SolarWindsAPM.logger.warn "[appoptics_apm/config] :sample_rate must be a number between 0 and 1000000 (1m) " \
                                   "(provided: #{value}), corrected to 0"
          value = 0
        end

        # Validate :sample_rate value
        unless value.between?(0, 1e6)
          value_1 = value
          value = value_1 < 0 ? 0 : 1_000_000
          SolarWindsAPM.logger.warn "[appoptics_apm/config] :sample_rate must be between 0 and 1000000 (1m) " \
                                   "(provided: #{value_1}), corrected to #{value}"
        end

        # Assure value is an integer
        @@config[key.to_sym] = value.to_i
        SolarWindsAPM.set_sample_rate(value) if SolarWindsAPM.loaded

      elsif key == :action_blacklist
        SolarWindsAPM.logger.warn "[appoptics_apm/config] :action_blacklist has been deprecated and no longer functions."

      elsif key == :blacklist
        SolarWindsAPM.logger.warn "[appoptics_apm/config] :blacklist has been deprecated and no longer functions."

      elsif key == :dnt_regexp
        if value.nil? || value == ''
          @@config[:dnt_compiled] = nil
        else
          @@config[:dnt_compiled] =
            Regexp.new(SolarWindsAPM::Config[:dnt_regexp], SolarWindsAPM::Config[:dnt_opts] || nil)
        end

      elsif key == :dnt_opts
        if SolarWindsAPM::Config[:dnt_regexp] && SolarWindsAPM::Config[:dnt_regexp] != ''
          @@config[:dnt_compiled] =
            Regexp.new(SolarWindsAPM::Config[:dnt_regexp], SolarWindsAPM::Config[:dnt_opts] || nil)
        end

      elsif key == :profiling_interval
        if value.is_a?(Integer) && value > 0
          value = [100, value].min
        else
          value = 10
        end
        @@config[:profiling_interval] = value
        # CProfiler may not be loaded yet, the profiler will send the value
        # after it is loaded
        SolarWindsAPM::CProfiler.set_interval(value) if defined? SolarWindsAPM::CProfiler

      elsif key == :transaction_settings
        if value.is_a?(Hash)
          SolarWindsAPM::TransactionSettings.compile_url_settings(value[:url])
        else
          SolarWindsAPM::TransactionSettings.reset_url_regexps
        end

      elsif key == :resque
        SolarWindsAPM.logger.warn "[appoptics_apm/config] :resque config is deprecated.  It is now split into :resqueclient and :resqueworker."
        SolarWindsAPM.logger.warn "[appoptics_apm/config] Called from #{Kernel.caller[0]}"

      elsif key == :include_url_query_params # DEPRECATED
        # Obey the global flag and update all of the per instrumentation
        # <tt>:log_args</tt> values.
        @@config[:rack][:log_args] = value

      elsif key == :include_remote_url_params # DEPRECATED
        # Obey the global flag and update all of the per instrumentation
        # <tt>:log_args</tt> values.
        @@http_clients.each do |i|
          @@config[i][:log_args] = value
        end

      elsif key == :tracing_mode
      #   CAN'T DO `set_tracing_mode` ANYMORE, ALL TRACING COMMUNICATION TO OBOE
      #   IS NOW HANDLED BY TransactionSettings
      #   SolarWindsAPM.set_tracing_mode(value.to_sym) if SolarWindsAPM.loaded

        # Make sure that the mode is stored as a symbol
        @@config[key.to_sym] = value.to_sym

      elsif key == :trigger_tracing_mode
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

SolarWindsAPM::Config.initialize
