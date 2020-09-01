require 'minitest_helper'

describe "Profiling: " do

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
    # puts traces.pretty_inspect

    assert_equal 1, traces.select { |tr| tr['Label'] == 'entry'}.size
    assert_equal 1, traces.select { |tr| tr['Label'] == 'exit'}.size

    tid = AppOpticsAPM::CProfiler.get_tid

    entry_trace = traces.find { |tr| tr['Label'] == 'entry'}
    assert_equal AppOpticsAPM::XTrace.edge_id(xtrace_context), entry_trace['SpanRef']
    assert_equal 17, entry_trace['Interval']
    assert_equal 'ruby', entry_trace['Language']
    assert_equal tid, entry_trace['TID']

    snapshot_trace = traces.find { |tr| tr['Label'] == 'info' }
    assert_equal AppOpticsAPM::XTrace.edge_id(xtrace_context), snapshot_trace['ContextOpId']
    assert_equal AppOpticsAPM::XTrace.edge_id(entry_trace['X-Trace']), snapshot_trace['Edge']
    assert_equal 17, snapshot_trace['NewFrames'].size
    assert_equal 'run', snapshot_trace['NewFrames'][0]['M']
    assert_equal 'AppOpticsAPM::Profiling', snapshot_trace['NewFrames'][0]['C']
    assert_equal 0, snapshot_trace['FramesExited']
    assert_equal 17, snapshot_trace['FramesCount']
    assert_equal [], snapshot_trace['SnapshotsOmitted']
    assert_equal tid, snapshot_trace['TID']

    exit_trace = traces.find { |tr| tr['Label'] == 'exit'}
    assert exit_trace['SnapshotsOmitted'].size > 0
    assert_equal AppOpticsAPM::XTrace.edge_id(snapshot_trace['X-Trace']), exit_trace['Edge']
    assert_equal tid, exit_trace['TID']
  end

  it 'logs snapshot after stack change' do
    AppOpticsAPM::Config[:profiling_interval] = 17
    AppOpticsAPM::SDK.start_trace(:trace) do
      AppOpticsAPM::Profiling.run do
        sleep 0.1
        # change the stack and restart recording of trace
        clear_all_traces(false)
        sleep 0.2
      end
    end

    traces = get_all_traces
    traces.select! { |tr| tr['Spec'] == "profiling" }
    assert_equal 3, traces.size

    assert_equal 'info', traces[0]['Label']
    assert_equal 'clear_all_traces', traces[0]['NewFrames'][0]['M']
    assert_equal 'Object', traces[0]['NewFrames'][0]['C']
    assert_equal 0, traces[0]['FramesExited']
    assert_equal 18, traces[0]['FramesCount']
    assert traces[0]['SnapshotsOmitted'].size > 0

    assert_equal 'info', traces[1]['Label']
    assert_equal [], traces[1]['NewFrames']
    assert_equal 1, traces[1]['FramesExited']
    assert_equal 17, traces[1]['FramesCount']
    assert traces[1]['SnapshotsOmitted'].size > 0

    assert_equal 'exit', traces[2]['Label']
    assert traces[2]['SnapshotsOmitted'].size > 0
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
    def recurse(num)
      num -= 1
      return if num == 0

      sleep 0.1 if num % 200 == 0 || num <= 10
      recurse(num)
    end

    AppOpticsAPM::SDK.start_trace(:trace) do
      AppOpticsAPM::Profiling.run do
        recurse(2100)
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
    assert_equal 20-1, traces.last['SnapshotsOmitted'].size,
                 "flaky, run again to match number of expected snapshots"
    # this may be flaky, it relies on rounding to smooth out variations in timing
    assert_equal 10, (traces.last['SnapshotsOmitted'][18]-traces.last['SnapshotsOmitted'][0])/18/1000,
                 "flaky, run again to match expected interval"
  end
end
