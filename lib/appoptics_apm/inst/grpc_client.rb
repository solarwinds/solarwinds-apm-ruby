# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module GRPC

    module ActiveCall
      if defined? ::GRPC
        StatusCodes = {}
        ::GRPC::Core::StatusCodes.constants.each { |code| StatusCodes[::GRPC::Core::StatusCodes.const_get(code)] = code }
      end

      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :request_response, ::GRPC::ActiveCall)
        ::AppOpticsAPM::Util.method_alias(klass, :client_streamer, ::GRPC::ActiveCall)
        ::AppOpticsAPM::Util.method_alias(klass, :server_streamer, ::GRPC::ActiveCall)
        ::AppOpticsAPM::Util.method_alias(klass, :bidi_streamer, ::GRPC::ActiveCall)
      end

      def grpc_tags(method_type, method)
        tags = { 'Spec' => 'rsc',
                 'RemoteURL' => "grpc://#{peer}#{method}",
                 'GRPCMethodType' => method_type,
                 'IsService' => 'True'
        }
        tags['Backtrace'] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:grpc_client][:collect_backtraces]
        tags
      end

      def request_response_with_appoptics(req, metadata: {})
        unary_response(req, type: 'UNARY', metadata: metadata, without: :request_response_without_appoptics)
      end

      def client_streamer_with_appoptics(req, metadata: {})
        unary_response(req, type: 'CLIENT_STREAMING', metadata: metadata, without: :client_streamer_without_appoptics)
      end

      def server_streamer_with_appoptics(req, metadata: {}, &blk)
        @tags = grpc_tags('SERVER_STREAMING', metadata[:method] || metadata_to_send[:method])
        AppOpticsAPM::API.log_entry('grpc_client', @tags)
        metadata['x-trace'] = AppOpticsAPM::Context.toString
        AppOpticsAPM::SDK.set_transaction_name(metadata[:method]) if AppOpticsAPM.transaction_name.nil?

        patch_receive_and_check_status # need to patch this so that log_exit can be called after the enum is consumed

        response = server_streamer_without_appoptics(req, metadata: metadata)
        block_given? ? response.each { |r| yield r } : response
      rescue => e
        # this check is needed because the exception may have been logged in patch_receive_and_check_status
        unless e.instance_variable_get(:@exn_logged)
          context_from_incoming
          AppOpticsAPM::API.log_exception('grpc_client', e)
          AppOpticsAPM::API.log_exit('grpc_client', exit_tags(@tags))
        end
        raise e
      end

      def bidi_streamer_with_appoptics(req, metadata: {}, &blk)
        @tags = grpc_tags('BIDI_STREAMING', metadata[:method] || metadata_to_send[:method])
        AppOpticsAPM::API.log_entry('grpc_client', @tags)
        metadata['x-trace'] = AppOpticsAPM::Context.toString
        AppOpticsAPM::SDK.set_transaction_name(metadata[:method]) if AppOpticsAPM.transaction_name.nil?

        patch_set_input_stream_done

        response = bidi_streamer_without_appoptics(req, metadata: metadata)
        block_given? ? response.each { |r| yield r } : response
      rescue => e
        unless e.instance_variable_get(:@exn_logged)
          context_from_incoming
          AppOpticsAPM::API.log_exception('grpc_client', e)
          AppOpticsAPM::API.log_exit('grpc_client', exit_tags(@tags))
        end
        raise e
      end

      private

      def unary_response(req, type: , metadata: , without:)
        tags = grpc_tags(type, metadata[:method] || metadata_to_send[:method])
        AppOpticsAPM::SDK.trace('grpc_client', tags) do
          metadata['x-trace'] = AppOpticsAPM::Context.toString
          AppOpticsAPM::SDK.set_transaction_name(metadata[:method]) if AppOpticsAPM.transaction_name.nil?
          begin
            send(without, req, metadata: metadata)
          ensure
            exit_tags(tags)
            context_from_incoming
          end
        end
      end

      def patch_receive_and_check_status
        def self.receive_and_check_status # need to patch this so that log_exit can be called after the enum is consumed
          super
          context_from_incoming
        rescue => e
          context_from_incoming
          AppOpticsAPM::API.log_exception('grpc_client', e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit('grpc_client', exit_tags(@tags))
        end
      end

      def patch_set_input_stream_done
        # need to patch this instance method so that log_exit can be called after the enum is consumed
        def self.set_input_stream_done
          return if status.nil?
          context_from_incoming
          if status.code > 0
            AppOpticsAPM::API.log_exception('grpc_client', $!)
          end
          AppOpticsAPM::API.log_exit('grpc_client', exit_tags(@tags))
          super
        end
      end

      def context_from_incoming
        xtrace ||= @call.trailing_metadata['x-trace'] if @call.trailing_metadata && @call.trailing_metadata['x-trace']
        xtrace ||= @call.metadata['x-trace'] if @call.metadata && @call.metadata['x-trace']
        AppOpticsAPM::Context.fromString(xtrace) if xtrace
      end

      def exit_tags(tags)
        # we need to translate the status.code, it is not the status.details we want, they are not matching 1:1
        tags['GRPCStatus'] ||= @call.status ? StatusCodes[@call.status.code].to_s : 'UNKNOWN'
        tags.delete('Backtrace')
        tags
      end
    end

  end
end

if defined?(::GRPC) && AppOpticsAPM::Config[:grpc_client][:enabled]
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting GRPC' if AppOpticsAPM::Config[:verbose]

  # Client side is instrumented in ActiveCall and ClientStub
  ::AppOpticsAPM::Util.send_include(::GRPC::ActiveCall, ::AppOpticsAPM::GRPC::ActiveCall)

  GRPC_ClientStub_ops = [:request_response, :client_streamer, :server_streamer, :bidi_streamer]
  module GRPC
    class ClientStub
      GRPC_ClientStub_ops.reject { |m| !method_defined?(m) }.each do |m|
        define_method("#{m}_with_appoptics") do |method, req, marshal, unmarshal, deadline: nil,
            return_op: false, parent: nil,
            credentials: nil, metadata: {}, &blk|

          metadata[:method] = method
          return send("#{m}_without_appoptics", method, req, marshal, unmarshal, deadline: deadline,
                      return_op: return_op, parent: parent,
                      credentials: credentials, metadata: metadata, &blk)
        end

        ::AppOpticsAPM::Util.method_alias(::GRPC::ClientStub, m)
      end

    end
  end
end