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
AppOpticsAPM::Config[:sample_rate] = 1000000 if defined? AppOpticsAPM

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
AppOpticsAPM::SDK.trace_method(Kids, :giggle) if defined? AppOpticsAPM
AppOpticsAPM::SDK.trace_method(Hola, :my_fun) if defined? AppOpticsAPM

AppOpticsAPM::Config.profiling = :enabled if defined? AppOpticsAPM
AppOpticsAPM::Config[:profiling_interval] = 1 if defined? AppOpticsAPM

unless AppOpticsAPM::SDK.appoptics_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end if defined? AppOpticsAPM


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

  def math
    2.times do
      # print "."
      2 + 3 * 4 ^ 5 / 6
    end
  end
end

def do_stuff

  threads = []

  puts "Main tid: #{AppOpticsAPM::CProfiler.get_tid}"

  # AppOpticsAPM::SDK.start_trace("threads") do
  #   AppOpticsAPM::Profiling.run do
  #     tid = AppOpticsAPM::CProfiler.get_tid
  #     puts tid

  5.times do |i|
    if i.odd?
      threads << Thread.new do
        sleep 0.1
        AppOpticsAPM::SDK.start_trace("thread-#{i}") do
          AppOpticsAPM::Profiling.run do
            tid = AppOpticsAPM::CProfiler.get_tid
            puts "2 - #{tid}, tracing? #{AppOpticsAPM.tracing?}"

            AppOpticsAPM::SDK.trace(:boo) do
              1_000_000.times do
                # File.open("foo_#{i}.txt", 'w') { |f| f.write(Time.now) }
                A.new
                # HaHaHa.new.laughing
                # i+i
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
        # sleep 0.2
      end
    end

  end

      # AppOpticsAPM::SDK.trace(:boo_main) do
      #   120.times do
      #     File.open('foo.txt', 'w') { |f| f.write(Time.now) }
      #     # HaHaHa.new.laughing
      #     # 2+2
      #     # A.new
      #   end
      # #   start = Time.new
      # #   while true
      # #     time = Time.new
      # #     if time - start > 2
      # #       raise StandardError
      # #     end
      # #
      # #   end
      # # rescue StandardError
      # #   puts "*** done waiting ***"
      # end
      # sleep 0.2
      threads.each { |th| th.join }
    end
#     puts AppopticsAPM::XTrace.task_id(AppopticsAPM::Context.toString)
#   end
# end

# do_stuff


def do_this
  name = ENV['AO_SETITIMER'] ? 'setitimer' : 'timer_create'
  1.times do
    AppOpticsAPM::SDK.start_trace(name) do

      # profile = StackProf.run(mode: :wall, interval: 20_000, raw: true) do
      start = Time.now
      AppOpticsAPM::Profiling.run do
      # sleep 0.5
      # 200_000.times do
      1_000_000.times do
        # sleep 0.01
        A.new
      end
      puts "Time spent profiling #{Time.now - start} seconds"
    end
      # return profile
  end
  # sleep 10
  end
end

do_stuff
# profile = do_this
# result = StackProf::Report.new(profile)
#
# puts
# puts result.data[:raw_timestamp_deltas]
# puts
# result.print_text
# puts
