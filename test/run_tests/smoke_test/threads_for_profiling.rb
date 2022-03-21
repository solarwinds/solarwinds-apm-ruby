# This file contains code for manual testing
# some of it is commented out, but may come in handy at some point

require 'prime'
require 'solarwinds_apm'
# require 'bson'
# require 'stackprof'
# require 'benchmark/ips'

def clear_all_traces
  if SolarWindsAPM.loaded && ENV['APPOPTICS_REPORTER'] == 'file'
    SolarWindsAPM::Reporter.clear_all_traces
    sleep 0.2 # it seems like the docker file system needs a bit of time to clear the file
  end
end

##
# get_all_traces
#
# Retrieves all traces written to the trace file
#
def get_all_traces
  if SolarWindsAPM.loaded && ENV['APPOPTICS_REPORTER'] =='file'
    sleep 0.2
    SolarWindsAPM::Reporter.get_all_traces
  else
    []
  end
end
SolarWindsAPM::Config[:sample_rate] = 1000000 if defined? SolarWindsAPM

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
    # ts = SolarWindsAPM::TransactionSettings.new
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

# SolarWindsAPM::SDK.trace_method(HaHaHa, :laughing)
# SolarWindsAPM::SDK.trace_method(Kids, :giggle) if defined? SolarWindsAPM
# SolarWindsAPM::SDK.trace_method(Hola, :my_fun) if defined? SolarWindsAPM

SolarWindsAPM::Config.profiling = :enabled if defined? SolarWindsAPM
SolarWindsAPM::Config[:profiling_interval] = 5 if defined? SolarWindsAPM

unless SolarWindsAPM::SDK.appoptics_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end if defined? SolarWindsAPM


class A
  def initialize
    pow
    self.class.newobj
    math
    # Array(1..100).reverse
    # File.open("log.txt", "w") { |f| f.write "#{Time.now} - timestamped!!!\n" }

  end

  def pow
    2 ** 100
  end

  def self.newobj
    Object.new
    Object.new
  end

  def A.math
    2.times do
      # print "."
      2 + 3 * 4 ^ 5 / 6
    end
  end
end

class Stuff
  def Stuff.do_stuff
    100.times { a.math }
  end
end
  # threads = []

  # puts "Main tid: #{SolarWindsAPM::CProfiler.get_tid}"
  # SolarWindsAPM::SDK.start_trace("main_thread") do
  #   SolarWindsAPM::Profiling.run do
  # 3.times do |i|
  #   threads << Thread.new do
  #     sleep 0.1
  # i = 0
  # 10.times do
  # SolarWindsAPM::SDK.start_trace("thread-#{i}") do
    # SolarWindsAPM::Profiling.run do
      # tid = SolarWindsAPM::CProfiler.get_tid
      # puts "thread tid: #{tid}, tracing? #{SolarWindsAPM.tracing?}"

      # SolarWindsAPM::SDK.trace(:boo) do
      #   50.times do
      # File.open("foo_#{i}.txt", 'w') { |f| f.write(Time.now) }
      # A.new
      # HaHaHa.new.laughing
      # i+i
      # sleep 1
      # end
    # end
  # end
  # end
  # sleep 0.2
  # end
# end
  # pid = fork do
    threads = []
    # puts "forked tid: #{SolarWindsAPM::CProfiler.get_tid}"
    # SolarWindsAPM::SDK.start_trace("main_thread") do
    #   SolarWindsAPM::Profiling.run do
    # 3.times do |i|
    #   threads << Thread.new do
    #     sleep 0.1
    #     SolarWindsAPM::SDK.start_trace("forked-thread-#{i}") do
    #       SolarWindsAPM::Profiling.run do
    #         tid = SolarWindsAPM::CProfiler.get_tid
    #         puts "forked thread tid: #{tid}, tracing? #{SolarWindsAPM.tracing?}"
    #
    #         # SolarWindsAPM::SDK.trace(:boo) do
    #           5000.times do
    #             # File.open("foo_#{i}.txt", 'w') { |f| f.write(Time.now) }
    #             A.new
    #             # HaHaHa.new.laughing
    #             # i+i
    #             # sleep 0.2
    #           end
    #         end
    #       end
    #     end
    #     # sleep 0.2
    #   # end
    #
    # end
    # sleep 1
    # threads.each { |th| th.join }
  # end
  # sleep 1
  # threads.each { |th| th.join }

  # pid2 = spawn(RbConfig.ruby, "-eputs'Hello, world!'")
  # Process.wait pid
  # puts "pid of forked process: #{pid}"
  # puts "pid of spawned process: #{pid2}"
  # puts Process.waitall
  # end
  # end
  #  puts SolarWindsAPM::XTrace.task_id(SolarWindsAPM::Context.toString)
# end

# require 'memory_profiler'
# MemoryProfiler.start
# puts "initial: #{`ps -o rss -p #{$$}`.lines.last}"
# 200.times do |i|


puts "initial: #{`ps -o rss -p #{$$}`.lines.last}"
# warmup
start = Time.now
SolarWindsAPM::SDK.start_trace("do_stuff") do
  5000.times do
    # SolarWindsAPM::Profiling.run do
    Stuff.do_stuff
  end
end
puts "warmup: #{`ps -o rss -p #{$$}`.lines.last}"
puts "warmup time: #{Time.now - start}"

start = Time.now
SolarWindsAPM::SDK.start_trace("do_stuff") do
  50000.times do
    # SolarWindsAPM::Profiling.run do
    Stuff.do_stuff
  end
end

puts "final: #{`ps -o rss -p #{$$}`.lines.last}"
puts "time: #{Time.now - start}"

# report = MemoryProfiler.stop
# report.pretty_print
# profile = do_this
# result = StackProf::Report.new(profile)
#
# puts
# puts result.data[:raw_timestamp_deltas]
# puts
# result.print_text
# puts
