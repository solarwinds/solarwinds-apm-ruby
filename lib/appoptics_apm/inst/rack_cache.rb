# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module RackCacheContext

    ###
    # This adds a controller.action like transaction name for
    # requests directly served from the cache without involving a controller.
    # The resulting transaction name is `rack-cache.<cache-store>`,
    # e.g. `rack-cache.memcached`
    #
    # It is not a full instrumentation, no span is added.
    #
    def call!(env)
      metastore_type = begin
        if options['rack-cache.metastore']
          options['rack-cache.metastore'].match(/^([^\:]*)\:/)[1]
        end || 'unknown_store'
      rescue
        'unknown_store'
      end

      env['appoptics_apm.action'] = metastore_type
      env['appoptics_apm.controller'] = 'rack-cache'

      super
    end
  end
end

if AppOpticsAPM::Config[:rack_cache][:transaction_name] && defined?(Rack::Cache::Context)
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting rack_cache' if AppOpticsAPM::Config[:verbose]
  Rack::Cache::Context.send(:prepend, ::AppOpticsAPM::RackCacheContext)
end
