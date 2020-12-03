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
  # 40.times do
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
          # sleep 0.05
        end
      end
    end
  # end
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

# require 'get_process_mem'


def do_stuff

  # puts "interval: #{AppOpticsAPM::Profiling.interval}"
  # 1.times do
  # AppOpticsAPM::SDK.trace(:all) do
  n = 30
  threads = []
  threads2 = []
  3.times do |i|
    threads[i] = Thread.new do
      tid = AppOpticsAPM::CProfiler.get_tid
      puts tid
      AppOpticsAPM::SDK.start_trace("thread_#{tid}") do
        # 500_000_000.times do |j|
          AppOpticsAPM::Profiling.run do
            # if (j % 20_000_000 == 0)
            #  mem = GetProcessMem.new
              # puts "#{tid} Memory used : #{mem.mb.round(6)} MB"
              # puts "#{tid} #{vm.chomp} #{rss.chomp}"
            # end
            # th1 = Thread.new do
            #   # AppOpticsAPM::SDK.start_trace(:th_1) do
            #   # AOProfiler.run do
            #   puts "th1 id: #{Thread.current.__id__}"
            #   puts "th1 tracing: #{AppOpticsAPM::Context.isValid}"
            #
            # (n*1).times do |i|
            # 10.times do |i|
            # puts "HaHaHa #{i}, #{Thread.current.object_id}" #if i%5 == 0
            AppOpticsAPM::SDK.trace(:boo) do
              HaHaHa.new.laughing
              i+i
              sleep 2
            end
            # end
            #

            # Kids.new.giggle
            # HaHaHa.new.laughing
            # Hola.my_fun

            # puts "... main thread waiting ..."


            # th1.join
            # puts AppOpticsAPM::Context.toString
            # puts AppOpticsAPM::XTrace.task_id(AppOpticsAPM::Context.toString)
          end
        end
      # end
    end
  end
  3.times do |i|
    threads2[i] = Thread.new do
      tid = AppOpticsAPM::CProfiler.get_tid
      puts tid
      AppOpticsAPM::SDK.start_trace("thread_#{tid}") do
        # 500_000_000.times do |j|
        AppOpticsAPM::Profiling.run do
          # if (j % 20_000_000 == 0)
          # mem = GetProcessMem.new
          # puts "#{tid} Memory used : #{mem.mb.round(6)} MB"
          # puts "#{tid} #{vm.chomp} #{rss.chomp}"
          # end
          # th1 = Thread.new do
          #   # AppOpticsAPM::SDK.start_trace(:th_1) do
          #   # AOProfiler.run do
          #   puts "th1 id: #{Thread.current.__id__}"
          #   puts "th1 tracing: #{AppOpticsAPM::Context.isValid}"
          #
          # (n*1).times do |i|
          # 10.times do |i|
          # puts "HaHaHa #{i}, #{Thread.current.object_id}" #if i%5 == 0
          AppOpticsAPM::SDK.trace(:boo) do
            HaHaHa.new.laughing
            i+i
            sleep 2
          end
          # end
          #

          # Kids.new.giggle
          # HaHaHa.new.laughing
          # Hola.my_fun

          # puts "... main thread waiting ..."


          # th1.join
          # puts AppOpticsAPM::Context.toString
          # puts AppOpticsAPM::XTrace.task_id(AppOpticsAPM::Context.toString)
        end
      end
      # end
    end
  end
  threads.each { |th| th.join }
  threads2.each { |th| th.join }
end

do_stuff

# BENCHMARK do_stuff with and without profiling
#
# profile = StackProf.run(mode: :wall, raw: true) do
# n = 1_000
# Benchmark.ips do |x|
#   x.config(:time => 60, :warmup => 10)
#   # x.report("warmup(10)") { AppOpticsAPM::Config.profiling_interval = 10; do_stuff }
#   x.report("50        ") { AppOpticsAPM::Config.profiling_interval = 50; clear_all_traces; do_stuff }
#   x.report("20        ") { AppOpticsAPM::Config.profiling_interval = 20; clear_all_traces; do_stuff }
#   x.report("10        ") { AppOpticsAPM::Config.profiling_interval = 10; clear_all_traces; do_stuff }
#   x.report("5         ") { AppOpticsAPM::Config.profiling_interval =  5; clear_all_traces; do_stuff }
#   x.report("disabled  ") { AppOpticsAPM::Config.profiling = :disabled;   clear_all_traces; do_stuff }
# end

# end
# puts profile.pretty_inspect

# puts aa.pretty_inspect if defined? aa
# duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
# puts "    >>>>> #{duration} <<<<<< "
# sleep 0.5
# traces = get_all_traces

# print_traces traces
# puts traces.pretty_inspect

