# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module GRPC

    if defined? ::GRPC
      StatusCodes = {}
      ::GRPC::Core::StatusCodes.constants.each { |code| StatusCodes[::GRPC::Core::StatusCodes.const_get(code)] = code }
    end

    module ActiveCall
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :request_response, ::GRPC::ActiveCall)
        ::AppOpticsAPM::Util.method_alias(klass, :client_streamer, ::GRPC::ActiveCall)
        ::AppOpticsAPM::Util.method_alias(klass, :server_streamer, ::GRPC::ActiveCall)
        ::AppOpticsAPM::Util.method_alias(klass, :bidi_streamer, ::GRPC::ActiveCall)
      end

      def grpc_tags(method_type, method)
        tags = {}
        tags['Spec'] = 'rsc'
        tags['RemoteURL'] = "#{peer}#{method}"
        tags['GRPCMethodType'] = method_type

        tags
      end

      def request_response_with_appoptics(req, metadata: {})
        unary_response(req, type: 'UNARY', metadata: metadata, without: :request_response_without_appoptics)
      end

      def client_streamer_with_appoptics(req, metadata: {})
        unary_response(req, type: 'CLIENT_STREAMING', metadata: metadata, without: :client_streamer_without_appoptics)
      end

      def unary_response(req, type: , metadata: , without:)
        tags = grpc_tags(type, metadata[:method])
        AppOpticsAPM::SDK.trace('grpc_client', tags) do
          metadata['x-trace'] = AppOpticsAPM::Context.toString
          begin
            send(without, req, metadata: metadata)
          rescue => e
            e.instance_variable_set(:@dont_log_backtraces, !AppOpticsAPM::Config[:grpc_client][:collect_backtraces])
            raise e
          ensure
            # we need to translate the status.code, it is not the status.details we want, they are not matching 1:1
            tags['GRPCStatus'] ||= @call.status ? AppOpticsAPM::GRPC::StatusCodes[@call.status.code].to_s : 'UNKNOWN'
            AppOpticsAPM::Context.fromString(metadata['x-trace']) if metadata['x-trace']
          end
        end
      end

      def server_streamer_with_appoptics(req, metadata:, &blk)
        @tags = grpc_tags('SERVER_STREAMING', metadata[:method])
        AppOpticsAPM::API.log_entry('grpc_client', @tags)
        metadata['x-trace'] = AppOpticsAPM::Context.toString

        patch_receive_and_check_status # need to patch this so that log_exit can be called after the enum is consumed

        response = server_streamer_without_appoptics(req, metadata: metadata)
        AppOpticsAPM::Context.fromString(metadata['x-trace']) if metadata['x-trace']
        if block_given?
          response.each { |r| yield r }
        else
          return response
        end
      rescue => e
        # this check is needed because the exception may have been logged in patch_receive_and_check_status
        unless e.instance_variable_get(:@exn_logged)
          e.instance_variable_set(:@dont_log_backtraces, !AppOpticsAPM::Config[:grpc_client][:collect_backtraces])
          AppOpticsAPM::API.log_exception('grpc_client', e)
          @tags['GRPCStatus'] = @call.status ? AppOpticsAPM::GRPC::StatusCodes[@call.status.code].to_s : 'UNKNOWN'
          AppOpticsAPM::API.log_exit('grpc_client', @tags)
        end
        raise e
      end

      def patch_receive_and_check_status
        def self.receive_and_check_status # need to patch this so that log_exit can be called after the enum is consumed
          super
        rescue => e
          e.instance_variable_set(:@dont_log_backtraces, !AppOpticsAPM::Config[:grpc_client][:collect_backtraces])
          AppOpticsAPM::API.log_exception('grpc_client', e)
          raise e
        ensure
          @tags['GRPCStatus'] = @call.status ? AppOpticsAPM::GRPC::StatusCodes[@call.status.code].to_s : 'UNKNOWN'
          AppOpticsAPM::API.log_exit('grpc_client', @tags)
        end
      end

      def bidi_streamer_with_appoptics(req, metadata: {}, &blk)
        @tags = grpc_tags('BIDI_STREAMING', metadata[:method])
        AppOpticsAPM::API.log_entry('grpc_client', @tags)
        metadata['x-trace'] = AppOpticsAPM::Context.toString

        patch_set_input_stream_done

        response = bidi_streamer_without_appoptics(req, metadata: metadata)
        AppOpticsAPM::Context.fromString(metadata['x-trace']) if metadata['x-trace']
        if block_given?
          response.each { |r| yield r }
        else
          return response
        end
      rescue => e
        # this check is necessary because the exception may have been logged in patch_set_input_stream_done
        unless e.instance_variable_get(:@exn_logged)
          e.instance_variable_set(:@dont_log_backtraces, !AppOpticsAPM::Config[:grpc_client][:collect_backtraces])
          AppOpticsAPM::API.log_exception('grpc_client', e)
          @tags['GRPCStatus'] = @call.status ? AppOpticsAPM::GRPC::StatusCodes[@call.status.code].to_s : 'UNKNOWN'
          AppOpticsAPM::API.log_exit('grpc_client', @tags)
        end
        raise e
      end

      def patch_set_input_stream_done
        def self.set_input_stream_done
          return if status.nil?
          if status.code > 0
            $!.instance_variable_set(:@dont_log_backtraces, !AppOpticsAPM::Config[:grpc_client][:collect_backtraces])
            AppOpticsAPM::API.log_exception('grpc_client', $!) unless $!.instance_variable_get(:@exn_logged)
          end
          @tags['GRPCStatus'] = AppOpticsAPM::GRPC::StatusCodes[status.code].to_s
          AppOpticsAPM::API.log_exit(:grpc_client, @tags)
          super
        end
      end
    end

  end
end

if defined?(::GRPC) && AppOpticsAPM::Config[:grpc_client][:enabled]
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting GRPC' if AppOpticsAPM::Config[:verbose]

  ::AppOpticsAPM::Util.send_include(::GRPC::ActiveCall, ::AppOpticsAPM::GRPC::ActiveCall)

  # patch ClientStub methods to include method name in metadata
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

  # Report __Init after fork when in Heroku
  AppOpticsAPM::API.report_init unless AppOpticsAPM.heroku?
end