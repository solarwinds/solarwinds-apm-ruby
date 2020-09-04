require 'minitest_helper'

describe "Profiling: " do
  class TestMethods
    class << self
      def recurse_with_sleep(num, sleep_every = 200)
        return if num == 0

        num -= 1
        sleep 0.1 if  num % sleep_every == 0
        recurse_with_sleep(num, sleep_every)
      end

      def recurse(num)
        return 0 if num == 0

        num -= 1
        1 + recurse(num) + 1 # make sure it can't optimize tail recursion
      end
    end
  end

  before do
    clear_all_traces
    @profiling_config = AppOpticsAPM::Config.profiling
    @profiling_interval_config = AppOpticsAPM::Config.profiling_interval

    AppOpticsAPM::Config[:profiling] = :enabled
  end

  after do
    AppOpticsAPM::Config[:profiling] = @profiling_config
    AppOpticsAPM::Config[:profiling_interval] = @profiling_interval_config
  end

  it 'logs start, snapshots, end' do
    AppOpticsAPM::Config[:profiling_interval] = 17
    xtrace_context = nil
    AppOpticsAPM::SDK.start_trace(:trace) do
      # it does not modify the tracing context
      xtrace_context = AppOpticsAPM::Context.toString
      AppOpticsAPM::Profiling.run do
        sleep 0.2
      end
      assert_equal xtrace_context, AppOpticsAPM::Context.toString
    end

    traces = get_all_traces
    traces.select! { |tr| tr['Spec'] == "profiling" }
    assert_equal 3, traces.size

    assert_equal 1, traces.select { |tr| tr['Label'] == 'entry'}.size
    assert_equal 1, traces.select { |tr| tr['Label'] == 'exit'}.size

    tid = AppOpticsAPM::CProfiler.get_tid

    entry_trace = traces.find { |tr| tr['Label'] == 'entry'}
    assert_equal AppOpticsAPM::XTrace.edge_id(xtrace_context), entry_trace['SpanRef']
    assert_equal 17, entry_trace['Interval']
    assert_equal 'ruby', entry_trace['Language']
    assert_equal tid, entry_trace['TID']

    # grabbing the first frame that reports 'sleep
    snapshot_trace = traces.find { |tr| tr['Label'] == 'info' && tr['NewFrames'][0]['M'] == 'sleep'}
    assert_equal AppOpticsAPM::XTrace.edge_id(xtrace_context), snapshot_trace['ContextOpId']
    assert_equal AppOpticsAPM::XTrace.edge_id(entry_trace['X-Trace']), snapshot_trace['Edge']
    assert_equal 18, snapshot_trace['NewFrames'].size
    assert_equal 'sleep', snapshot_trace['NewFrames'][0]['M'] # obviously
    assert_equal 'Kernel', snapshot_trace['NewFrames'][0]['C']
    assert_equal 0, snapshot_trace['FramesExited']
    assert_equal 18, snapshot_trace['FramesCount']
    assert_equal [], snapshot_trace['SnapshotsOmitted']
    assert_equal tid, snapshot_trace['TID']

    exit_trace = traces.find { |tr| tr['Label'] == 'exit'}
    assert exit_trace['SnapshotsOmitted'].size > 0
    assert_equal AppOpticsAPM::XTrace.edge_id(snapshot_trace['X-Trace']), exit_trace['Edge']
    assert_equal tid, exit_trace['TID']
  end

  it 'logs snapshot after stack change' do
    AppOpticsAPM::Config[:profiling_interval] = 1
    AppOpticsAPM::SDK.start_trace(:trace) do
      AppOpticsAPM::Profiling.run do
        sleep 0.1
        # use a predictable method, that doesn't call other methods
        # since it is recursive, don't recurse too much,
        # exploding stack is a different test
        TestMethods.recurse(1500)
        TestMethods.recurse(1500)
        TestMethods.recurse(1500)
        TestMethods.recurse(1500)
        TestMethods.recurse(1500)
        TestMethods.recurse(1500)
        TestMethods.recurse(1500)
      end
    end

    traces = get_all_traces
    traces.select! { |tr| tr['Spec'] == 'profiling' && tr['Label'] == 'info' }

    traces.select! { |tr| tr['NewFrames'][0]['M'] == 'recurse' }

    assert_equal 'info', traces[0]['Label']                # obviously
    assert_equal 'recurse', traces[0]['NewFrames'][0]['M'] # obviously
    assert_equal 'TestMethods', traces[0]['NewFrames'][0]['C']
    assert_equal 1, traces[0]['FramesExited']
    assert_equal 18, traces[0]['FramesCount']
    assert traces[0]['SnapshotsOmitted'].size > 0
  end

  # VERY IMPORTANT TEST
  # segfault likely if it doesn't pass
  it "doesn't fail if there are many omitted snapshots" do
    AppOpticsAPM::Config[:profiling_interval] = 1
    AppOpticsAPM::SDK.start_trace(:trace) do
      AppOpticsAPM::Profiling.run do
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

    AppOpticsAPM::SDK.start_trace(:trace) do
      AppOpticsAPM::Profiling.run do
        TestMethods.recurse_with_sleep(2100, 200)
      end
    end
    # it didn't crash, return success just for stats
    assert true
  end

  it 'samples at the configured interval' do
    AppOpticsAPM::Config[:profiling_interval] = 10
    AppOpticsAPM::SDK.start_trace(:trace) do
      AppOpticsAPM::Profiling.run do
        sleep 0.2
      end
    end

    traces = get_all_traces
    traces.select! { |tr| tr['Spec'] == 'profiling' }

    # this may be flaky, because there it is expected that there can be
    # small variations in the timing of the snapshots
    assert traces.last['SnapshotsOmitted'].size >= 18
    # this may be flaky, it relies on rounding to smooth out variations in timing
    average_interval = (traces.last['SnapshotsOmitted'][16]-traces.last['SnapshotsOmitted'][0])/16/1000
    assert (average_interval >= 9 && average_interval <= 11)
  end

  it 'profiles inside threads' do
    AppOpticsAPM::Config[:profiling_interval] = 1

    threads = []
    tids = []
    AppOpticsAPM::SDK.start_trace("trace_main") do
      AppOpticsAPM::Profiling.run do
        5.times do
          th = Thread.new do
            tid = AppOpticsAPM::CProfiler.get_tid
            tids << tid
            AppOpticsAPM::SDK.start_trace("trace_#{tid}") do
              AppOpticsAPM::Profiling.run do
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
    traces = get_all_traces
    traces.select! { |tr| tr['Spec'] == 'profiling' }

    tids.each do |tid|
      assert_equal 3, traces.select { |tr| tr['TID'] == tid }.size
    end
  end

  it 'does not shorten sleep' do
    AppOpticsAPM::Config[:profiling_interval] = 1
    AppOpticsAPM::SDK.start_trace(:trace) do
      AppOpticsAPM::Profiling.run do
        start = Time.now
        sleep 2
        # as precise as it gets, good enough to test that sleep isn't interrupted
        assert_equal 2.0, (Time.now - start).round(1)
      end
    end
  end

end
