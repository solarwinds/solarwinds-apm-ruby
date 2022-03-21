require 'minitest_helper'

describe "Profiling: " do
  class TestMethods
    class << self
      def recurse_with_sleep(num, sleep_every = 200)
        return if num == 0

        num -= 1
        sleep 0.1 if num % sleep_every == 0
        recurse_with_sleep(num, sleep_every)
      end

      def recurse(num)
        return 0 if num == 0

        num -= 1
        1 + recurse(num) + 1 # make sure it can't optimize tail recursion
      end

      def sleep_a_bit(secs)
        sleep secs
      end
    end
  end

  before do
    clear_all_traces
    @profiling_config = SolarWindsAPM::Config.profiling
    @profiling_interval_config = SolarWindsAPM::Config.profiling_interval

    SolarWindsAPM::Config[:profiling] = :enabled
  end

  after do
    SolarWindsAPM::Config[:profiling] = @profiling_config
    SolarWindsAPM::Config[:profiling_interval] = @profiling_interval_config
  end

  it 'check entry, edges, and exit' do
    SolarWindsAPM::Config[:profiling_interval] = 13
    xtrace_context = nil
    SolarWindsAPM::SDK.start_trace(:trace) do
      # it does not modify the tracing context
      xtrace_context = SolarWindsAPM::Context.toString
      SolarWindsAPM::Profiling.run do
        TestMethods.sleep_a_bit(0.1)
      end
      assert_equal xtrace_context, SolarWindsAPM::Context.toString
    end

    traces = get_all_traces
    traces.select! { |tr| tr['Spec'] == "profiling" }

    assert_equal 1, traces.select { |tr| tr['Label'] == 'entry' }.size, "no entry found #{traces.pretty_inspect}"
    assert traces.select { |tr| tr['Label'] == 'exit' }.size >= 1
    assert_equal 1, traces.select { |tr| tr['Label'] == 'exit' }.size, "no exit found"

    tid = SolarWindsAPM::CProfiler.get_tid

    entry_trace = traces.find { |tr| tr['Label'] == 'entry' }
    assert_equal SolarWindsAPM::TraceString.span_id(xtrace_context), entry_trace['SpanRef']
    assert_equal 13, entry_trace['Interval']
    assert_equal 'ruby', entry_trace['Language']
    assert_equal tid, entry_trace['TID']

    # check an edge
    snapshot_trace = traces.find { |tr| tr['Label'] == 'info' }
    assert_equal SolarWindsAPM::TraceString.span_id(xtrace_context), snapshot_trace['ContextOpId']
    assert_equal SolarWindsAPM::TraceString.span_id(entry_trace['X-Trace']), snapshot_trace['Edge']

    # check last edge
    snapshot_trace = traces.select { |tr| tr['Label'] == 'info' }.last
    exit_trace = traces.find { |tr| tr['Label'] == 'exit' }
    assert (exit_trace['SnapshotsOmitted'].size > 0), "no omitted snapshot found"
    assert_equal SolarWindsAPM::TraceString.span_id(snapshot_trace['X-Trace']), exit_trace['Edge']
    assert_equal tid, exit_trace['TID']
  end

  it 'logs snapshot after stack change' do
    SolarWindsAPM::Config[:profiling_interval] = 1
    SolarWindsAPM::SDK.start_trace(:trace) do
      SolarWindsAPM::Profiling.run do
        # use a predictable method
        TestMethods.sleep_a_bit(0.1)
        # since it is recursive,
        # don't recurse too deeply, exploding the stack is a different test
        20.times do
          TestMethods.recurse(1500)
        end
      end
    end

    traces = get_all_traces
    traces.select! { |tr| tr['Spec'] == 'profiling' && tr['Label'] == 'info' }
    traces.select! { |tr| tr['NewFrames'][0]['M'] == 'recurse' }

    assert_equal 'info', traces[0]['Label']                # obviously
    assert_equal 'recurse', traces[0]['NewFrames'][0]['M'] # obviously
    assert_equal 'TestMethods', traces[0]['NewFrames'][0]['C']
    assert traces[0]['FramesExited'] >= 1
    assert (15 < traces[0]['FramesCount']) # different number in travis
  end

  # VERY IMPORTANT TEST
  # segfault likely if it doesn't pass
  it "doesn't fail if there are many omitted snapshots" do
    SolarWindsAPM::Config[:profiling_interval] = 1
    SolarWindsAPM::SDK.start_trace(:trace) do
      SolarWindsAPM::Profiling.run do
        # the buffer for omitted snapshots holds 2048 timestamps
        # 3 secs at an interval of 1 should produce about 3000
        sleep 3
      end
    end
    # it didn't crash, return success just for stats
    assert true
  end

  it "doesn't fail if the stack is large" do
    # create a large stack of more than the BUF_SIZE of 2048

    SolarWindsAPM::SDK.start_trace(:trace) do
      SolarWindsAPM::Profiling.run do
        TestMethods.recurse_with_sleep(2100, 200)
      end
    end
    # it didn't crash, return success just for stats
    assert true
  end

  it 'samples at the configured interval' do
    SolarWindsAPM::Config[:profiling_interval] = 10
    SolarWindsAPM::SDK.start_trace(:trace) do
      SolarWindsAPM::Profiling.run do
        sleep 0.2
      end
    end

    traces = get_all_traces

    traces.select! { |tr| tr['Spec'] == 'profiling' }

    num = 0
    traces.each do |tr|
      if tr['SnapshotsOmitted']
        num += tr['SnapshotsOmitted'].size
      end
      num += 1
    end
    assert (num >= 15), "Number of Traces+SnapshotsOmitted is only #{num} should be >= 15 , #{traces.pretty_inspect}"

    duration = traces.last['Timestamp_u'] - traces[0]['Timestamp_u']
    average_interval = (duration / (num - 1)) / 1000.0
    assert (average_interval >= 9 && average_interval <= 11),
           "average interval should be >= 9 and <= 11, actual #{average_interval}, #{num}, #{duration}\n#{traces.pretty_inspect}"
  end

  it 'profiles inside threads' do
    SolarWindsAPM::Config[:profiling_interval] = 1

    threads = []
    tids = []
    SolarWindsAPM::SDK.start_trace("trace_main") do
      SolarWindsAPM::Profiling.run do
        tid = SolarWindsAPM::CProfiler.get_tid
        tids << tid
        5.times do
          th = Thread.new do
            tid = SolarWindsAPM::CProfiler.get_tid
            tids << tid
            SolarWindsAPM::SDK.start_trace("trace_#{tid}") do
              SolarWindsAPM::Profiling.run do
                # The threads have to be busy, otherwise
                # they don't get profiled because they are not executing
                20.times do
                  TestMethods.recurse(1500)
                end
              end
            end
          end
          threads << th
        end
        threads.each(&:join)
      end
    end
    sleep 1
    traces = get_all_traces
    traces.select! { |tr| tr['Spec'] == 'profiling' }

    # for each thread we want to see an entry and exit trace
    tids.each do |tid|
      assert traces.select { |tr| tr['TID'] == tid && tr['Label'] == 'entry' }
      assert traces.select { |tr| tr['TID'] == tid && tr['Label'] == 'exit' }
    end
  end

  it 'does not shorten sleep' do
    SolarWindsAPM::Config[:profiling_interval] = 1
    SolarWindsAPM::SDK.start_trace(:trace) do
      SolarWindsAPM::Profiling.run do
        start = Time.now
        sleep 2
        # as precise as it gets, good enough to test that sleep isn't interrupted
        assert_equal 2.0, (Time.now - start).round(1)
      end
    end
  end

end
