# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

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
        info = self.instance_method(method_name).source_location
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
