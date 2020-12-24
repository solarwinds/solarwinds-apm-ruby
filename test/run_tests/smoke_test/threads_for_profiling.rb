require 'prime'
require 'appoptics_apm'
require 'bson'
# require '/appoptics_apm/test/minitest_helper.rb'
# require 'stackprof'
# require 'benchmark/ips'

def clear_all_traces
  if AppOpticsAPM.loaded && ENV['APPOPTICS_REPORTER'] == 'file'
    AppOpticsAPM::Reporter.clear_all_traces
    sleep 0.2 # it seems like the docker file system needs a bit of time to clear the file
  end
end

##
# get_all_traces
#
# Retrieves all traces written to the trace file
#
def get_all_traces
  if AppOpticsAPM.loaded && ENV['APPOPTICS_REPORTER'] =='file'
    sleep 0.2
    AppOpticsAPM::Reporter.get_all_traces
  else
    []
  end
end
AppOpticsAPM::Config[:sample_rate] = 1000000

def print_traces(traces, more_keys = [])
  return unless traces.is_a?(Array) # so that in case the traces are sent to the collector, tests will fail but not barf
  indent = ''
  puts "\n"
  traces.each do |trace|
    indent += '  ' if trace["Label"] == "entry"

    puts "#{indent}X-Trace: #{trace["X-Trace"]}"
    puts "#{indent}Label:   #{trace["Label"]}"
    puts "#{indent}Layer:   #{trace["Layer"]}"

    more_keys.each { |key| puts "#{indent}#{key}:   #{trace[key]}" if trace[key] }

    indent = indent[0...-2] if trace["Label"] == "exit"
  end
  puts "\n"
end


def massive_fun(temps)
  aa = Array.new
  4.times do
  5.times do
    5.times do
      4.times do
        temps.sort.reverse
        aa << "it is too #{temps.shuffle!.first}"
        aa.reverse.size
        # puts "............................... #{aa.last} ......................."
        aa.delete_if do |a|
          a =~ /[l|r]/
        end
        # sleep 0.01
      end
    end
  end
  # sleep 0.01
  end
end

class Hola
  def self.my_fun
    # temps = ['cold', 'warm', 'chilly','hot']
    1.times do
      sum_prime = 0
      Prime.each(10000) do |prime|
        sum_prime += prime
        sum_prime/2
      end
    end
  end
end

class Kids
  def giggle
    temps = ['colder', 'warmer', 'chilly','hot']
    # ts = AppOpticsAPM::TransactionSettings.new
    # 100_000.times do
    #   ts.to_s
    # end
    # massive_fun(temps)
  end
end

class HaHaHa
  def laughing
    temps = ['colder', 'warmer', 'chilly','hot']
    massive_fun(temps)
  end
end

# AppOpticsAPM::SDK.trace_method(HaHaHa, :laughing)
AppOpticsAPM::SDK.trace_method(Kids, :giggle)
AppOpticsAPM::SDK.trace_method(Hola, :my_fun)

AppOpticsAPM::Config.profiling = :enabled

unless AppOpticsAPM::SDK.appoptics_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end

def do_stuff
  AppOpticsAPM::Config[:profiling] = :enabled
  AppOpticsAPM::Config[:profiling_interval] = 100

  threads = []

  puts "Main tid: #{AppOpticsAPM::CProfiler.get_tid}"

  AppOpticsAPM::SDK.start_trace("threads") do
    AppOpticsAPM::Profiling.run do
      tid = AppOpticsAPM::CProfiler.get_tid
      puts tid

      5.times do |i|
        threads[i] = Thread.new do
          AppOpticsAPM::SDK.start_trace("thread-#{i}") do
            AppOpticsAPM::Profiling.run do
              tid = AppOpticsAPM::CProfiler.get_tid
              puts "2 - #{tid}, tracing? #{AppOpticsAPM.tracing?}"

              AppOpticsAPM::SDK.trace(:boo) do
                30.times do
                  HaHaHa.new.laughing
                  i+i
                  # sleep 0.2
                end
              # start = Time.new
              #   while true
              #     time = Time.new
              #     if time - start > 2
              #       raise StandardError
              #     end
              #
              #   end
              # rescue StandardError
              #   puts "*** done waiting ***"
              end
            end
          end
        end

      end

      AppOpticsAPM::SDK.trace(:boo_main) do
        80.times do
          HaHaHa.new.laughing
          2+2
        end
      #   start = Time.new
      #   while true
      #     time = Time.new
      #     if time - start > 2
      #       raise StandardError
      #     end
      #
      #   end
      # rescue StandardError
      #   puts "*** done waiting ***"
      end
      # sleep 0.2
      threads.each { |th| th.join }
    end
    puts AppopticsAPM::XTrace.task_id(AppopticsAPM::Context.toString)
  end
end

do_stuff
