# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe_metal
  include_package 'com.tracelytics.joboe.Context'
  import 'com.tracelytics.joboe.Context'

  class Context

    def self.log(layer, label, options = {}, with_backtrace = true)
      evt = Oboe::Context.createEvent()
      evt.addInfo("Layer", layer.to_s)
      evt.addInfo("Label", label.to_s)

      options.each_pair do |k, v|
        evt.addInfo(k.to_s, v.to_s)
      end

      evt.addInfo("Backtrace", Kernel.caller.join("\r\n")) if with_backtrace

      Oboe.reporter.send(evt)
    end

    def self.layer_op=(op)
      @layer_op = op
    end

    def self.layer_op
      @layer_op
    end

    def self.tracing_layer_op?(operation)
      if operation.is_a?(Array)
        return operation.include?(@layer_op)
      else
        return @layer_op == operation
      end
    end

    def self.toString
      md = getMetadata.toString
    end

    def self.clear
      clearMetadata
    end

    def self.get
      getMetadata
    end
  end
end

module OboeMethodProfiling
  def self.included klass
    klass.extend ClassMethods
  end

  module ClassMethods
    def profile_method(method_name, profile_name, store_args=false, store_return=false, profile=false)
      #this only gets file and line where profiling is turned on, presumably
      #right after the function definition. ruby 1.9 has nice introspection (Method.source_location)
      #but its appears no such luck for ruby 1.8
      version = RbConfig::CONFIG['ruby_version']
      file = nil
      line = nil
      if version and version.match(/^1.9/)
        info = self.method(method_name).source_location
        if !info.nil?
          file = info[0]
          line = info[1] 
        end
      else
        info = Kernel.caller[0].split(':')
        file = info.first
        line = info.last
      end

      #profiling via ruby-prof, is it possible to get return value of profiled code?
      code = "def _oboe_profiled_#{method_name}(*args, &block)
                def pps(*args)
                  old_out = $stdout
                  begin
                    s = StringIO.new
                    $stdout = s
                    pp(*args)
                  ensure
                    $stdout = old_out
                  end
                  s.string
                end

                # file and line number are fetched in Context.log
                # because we have access to the correct backtrace there
                entry_kvs = {'Language'     => 'ruby',
                             'ProfileName'  => '#{profile_name}',
                             'FunctionName' => '#{method_name}',
                             'Class'        => self.class.to_s.rpartition('::').last,
                             'Module'       => self.class.to_s.rpartition('::').first,
                             'File'         => '#{file}',
                             'LineNumber'    => '#{line}' 
                            }

                if #{store_args}
                  entry_kvs['Args'] = pps *args
                end

                Oboe::Context.log(nil, 'profile_entry', entry_kvs)

                ret = _oboe_orig_#{method_name}(*args, &block)

                exit_kvs =  {'Language'     => 'ruby',
                             'ProfileName'  => '#{profile_name}'
                            }
                
                if #{store_return}
                  exit_kvs['ReturnValue'] = pps ret
                end

                Oboe::Context.log(nil, 'profile_exit', exit_kvs)

                ret
              end"

      class_eval code, __FILE__, __LINE__
      alias_method "_oboe_orig_#{method_name}", method_name
      alias_method method_name, "_oboe_profiled_#{method_name}"
    end
  end
end
  
module Oboe
  include Oboe_metal
  
  include_package 'com.tracelytics.joboe.Event'
  import 'com.tracelytics.joboe.Event'
  include_package 'com.tracelytics.joboe'
  import 'com.tracelytics.joboe'
  include_package 'com.tracelytics.agent.Agent'
  import 'com.tracelytics.agent.Agent'
  
  class Event
    def self.metadataString(evt)
      evt.getMetadata.toHexString
    end
  end

  def self.startAgent
    Java::ComTracelyticsAgent::Agent.premain('', nil)
  end

  def UdpReporter
    Java::ComTracelyticsJoboe
  end
  
  module Metadata
    Java::ComTracelyticsJoboeMetaData
  end


  # TODO: Ensure that the :tracing_mode is set to "always", "through", or "never"
  Config = {
    :tracing_mode => "through",
    :reporter_host => "127.0.0.1",
    :sample_rate => 1000000
  }

  def self.passthrough?
    ["always", "through"].include?(Oboe::Config[:tracing_mode])
  end

  def self.always?
    Oboe::Config[:tracing_mode] == "always"
  end

  def self.through?
    Oboe::Config[:tracing_mode] == "through"
  end

  def self.never?
    Oboe::Config[:tracing_mode] == "never"
  end

  def self.now?
    Oboe::Context.isValid and not Oboe.never?
  end

  def self.start?
    not Oboe::Context.isValid and Oboe.always?
  end

  def self.continue?
    Oboe::Context.isValid and not Oboe.never?
  end

  def self.log(layer, label, options = {})
    Context.log(layer, label, options = options)
  end

  def self.reporter
    if !@reporter
      @reporter = Oboe::UDPReporter.new(Oboe::Config[:reporter_host], 2394)
    end

    return @reporter
  end

  module Reporter
    def self.sendReport(evt)
      evt.report
    end
  end
end

Oboe.startAgent

