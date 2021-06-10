require 'prime'
require 'appoptics_apm'

AppOpticsAPM::Config[:sample_rate] = 1000000 if defined? AppOpticsAPM

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

class HaHaHa
  def laughing
    temps = ['colder', 'warmer', 'chilly','hot']
    massive_fun(temps)
  end
end

AppOpticsAPM::Config.profiling = :enabled if defined? AppOpticsAPM
AppOpticsAPM::Config[:profiling_interval] = 5 if defined? AppOpticsAPM

unless AppOpticsAPM::SDK.appoptics_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end if defined? AppOpticsAPM

class A
  def initialize
    pow
    self.class.newobj
    math
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
    100.times { A.math }
  end
end

ENV['WITH_PROFILING']='true'

puts "initial: #{`ps -o rss -p #{$$}`.lines.last}"
# warmup
start = Time.now
th = []

5.times do
  fork do
    3_000.times do
      t = Thread.new do
        AppOpticsAPM::SDK.start_trace("do_stuff") do
          1_000.times do
            if ENV['WITH_PROFILING'] == 'true'
              AppOpticsAPM::Profiling.run do
                Stuff.do_stuff
              end
            else
              Stuff.do_stuff
            end
          end
        end
      end
      th << t
    end
    th.each { |t| t.join }
  end
  pid = Process.wait
end

puts "warmup: #{`ps -o rss -p #{$$}`.lines.last}"
puts "warmup time: #{Time.now - start}"

start = Time.now
5.times do
  fork do
    3_000.times do
      t = Thread.new do
        AppOpticsAPM::SDK.start_trace("do_stuff") do
          4_000.times do
            if ENV['WITH_PROFILING'] == 'true'
              AppOpticsAPM::Profiling.run do
                Stuff.do_stuff
              end
            else
              Stuff.do_stuff
            end
          end
        end
      end
      th << t
    end
    th.each { |t| t.join }
    end
  pid = Process.wait
end

puts "final: #{`ps -o rss -p #{$$}`.lines.last}"
puts "time: #{Time.now - start}"
