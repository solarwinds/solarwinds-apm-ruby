# frozen_string_literal: true

#--
# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.
#++
#

##
# Tracing for the graphql gem
#
# This instrumentation is autoloaded when a class inherits GraphQL::Schema
# no need to call `tracer` or `use`


if defined?(GraphQL::Tracing) && !(SolarWindsAPM::Config[:graphql][:enabled] == false)
  module GraphQL
    module Tracing

      class SolarWindsAPMTracing < GraphQL::Tracing::PlatformTracing
        # These GraphQL events will show up as 'graphql.prep' spans
        PREP_KEYS = ['lex', 'parse', 'validate', 'analyze_query', 'analyze_multiplex'].freeze
        EXEC_KEYS = ['execute_multiplex', 'execute_query', 'execute_query_lazy'].freeze

        self.platform_keys = {
          'lex' => 'lex',
          'parse' => 'parse',
          'validate' => 'validate',
          'analyze_query' => 'analyze_query',
          'analyze_multiplex' => 'analyze_multiplex',
          'execute_multiplex' => 'execute_multiplex',
          'execute_query' => 'execute_query',
          'execute_query_lazy' => 'execute_query_lazy'
        }

        def platform_trace(platform_key, _key, data)
          return yield if gql_config[:enabled] == false

          layer = span_name(platform_key)
          kvs = metadata(data, layer)
          kvs[:Key] = platform_key if (PREP_KEYS + EXEC_KEYS).include?(platform_key)

          transaction_name(kvs[:InboundQuery]) if kvs[:InboundQuery] && layer == 'graphql.execute'

          ::SolarWindsAPM::SDK.trace(layer, kvs: kvs) do
            kvs.clear # we don't have to send them twice
            yield
          end
        end

        def platform_field_key(type, field)
          "graphql.#{type.graphql_name}.#{field.name}"
        end

        def platform_authorized_key(type)
          "graphql.#{type.graphql_name}.authorized"
        end

        def platform_resolve_type_key(type)
          "graphql.#{type.graphql_name}.resolve_type"
        end

        private

        def gql_config
          ::SolarWindsAPM::Config[:graphql] ||= {}
        end

        def transaction_name(query)
          return if gql_config[:transaction_name] == false ||
            ::SolarWindsAPM::SDK.get_transaction_name

          split_query = query.strip.split(/\W+/, 3)
          split_query[0] = 'query' if split_query[0].empty?
          name = "graphql.#{split_query[0..1].join('.')}"

          ::SolarWindsAPM::SDK.set_transaction_name(name)
        end

        def multiplex_transaction_name(names)
          return if gql_config[:transaction_name] == false ||
            ::SolarWindsAPM::SDK.get_transaction_name

          name = "graphql.multiplex.#{names.join('.')}"
          name = "#{name[0..251]}..." if name.length > 254

          ::SolarWindsAPM::SDK.set_transaction_name(name)
        end

        def span_name(key)
          return 'graphql.prep' if PREP_KEYS.include?(key)
          return 'graphql.execute' if EXEC_KEYS.include?(key)

          key[/^graphql\./] ? key : "graphql.#{key}"
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def metadata(data, layer)
          kvs = data.keys.map do |key|
            case key
            when :context
              graphql_context(data[:context], layer)
            when :query
              graphql_query(data[:query])
            when :query_string
              graphql_query_string(data[:query_string])
            when :multiplex
              graphql_multiplex(data[:multiplex])
            else
              [key, data[key]] unless key == :path # we get the path from context
            end
          end

          kvs.compact.flatten.each_slice(2).to_h.merge(Spec: 'graphql')
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def graphql_context(context, layer)
          context.errors && context.errors.each do |err|
            SolarWindsAPM::API.log_exception(layer, err)
          end

          [[:Path, context.path.join('.')]]
        end

        def graphql_query(query)
          return [] unless query

          query_string = query.query_string
          query_string = remove_comments(query_string) if gql_config[:remove_comments] != false
          query_string = sanitize(query_string) if gql_config[:sanitize_query] != false

          [[:InboundQuery, query_string],
           [:Operation, query.selected_operation_name]]
        end

        def graphql_query_string(query_string)
          query_string = remove_comments(query_string) if gql_config[:remove_comments] != false
          query_string = sanitize(query_string) if gql_config[:sanitize_query] != false

          [:InboundQuery, query_string]
        end

        def graphql_multiplex(data)
          names = data.queries.map(&:operations).map(&:keys).flatten.compact
          multiplex_transaction_name(names) if names.size > 1

          [:Operations, names.join(', ')]
        end

        def sanitize(query)
          return unless query

          # remove arguments
          query.gsub(/"[^"]*"/, '"?"')                 # strings
               .gsub(/-?[0-9]*\.?[0-9]+e?[0-9]*/, '?') # ints + floats
               .gsub(/\[[^\]]*\]/, '[?]')              # arrays
        end

        def remove_comments(query)
          return unless query

          query.gsub(/#[^\n\r]*/, '')
        end
      end
    end
  end

  module SolarWindsAPM
    module GraphQLSchemaPrepend

      # Graphql doesn't check if a plugin is added twice
      # we would get double traces
      def use(plugin, **options)
        super unless self.plugins.find { |pl| pl[0].to_s == plugin.to_s }

        self.plugins
      end

      def inherited(subclass)
        subclass.use(GraphQL::Tracing::SolarWindsAPMTracing)
        super
      end
    end

    module GraphQLErrorPrepend
      def initialize(*args)
        super
        bt = SolarWindsAPM::API.backtrace(1)
        set_backtrace(bt) unless self.backtrace
      end
    end
  end


  if Gem.loaded_specs['graphql'] && Gem.loaded_specs['graphql'].version >= Gem::Version.new('1.8.0')
    SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting GraphQL' if SolarWindsAPM::Config[:verbose]
    if defined?(GraphQL::Schema)
      GraphQL::Schema.singleton_class.prepend(SolarWindsAPM::GraphQLSchemaPrepend)
    end

    if defined?(GraphQL::Error)
      GraphQL::Error.prepend(SolarWindsAPM::GraphQLErrorPrepend)
    end
  end
end
