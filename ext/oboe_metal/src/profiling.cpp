// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "profiling.h"
#include "logging.h"


string app_root;
static int running = 0;

typedef struct frames_struct {
    bool running_p = false;
    // oboe_metadata_t *md;
    uint8_t prof_op_id[OBOE_MAX_OP_ID_LEN];

    struct timeval prev_timestamp;
    VALUE prev_frames_buffer[BUF_SIZE];
    int prev_num = 0;
    long omitted[BUF_SIZE];
    int omitted_num = 0;
    // eventually add "other thread" info
} frames_struct_t;

unordered_map<pid_t, frames_struct_t> prof_data;
static struct timeval timestamp;
// need to initialize here, hangs if it is done inside the signal handler
static VALUE frames_buffer[BUF_SIZE];
static int lines_buffer[BUF_SIZE];
static vector<frame_t> new_frames(BUF_SIZE);

boost::lockfree::spsc_queue<msg_t, boost::lockfree::capacity<1024> > spsc_queue;


// static bool in_gc_p;
// static long signal_ts;
// static long total_time = 0;
// static int num_profiles = 0;

long interval = 10;  // in milliseconds, initializing in case ruby forgets to

// void calculate_overhead() {
//     gettimeofday(&timestamp, NULL);
//     long end_ts = (long)timestamp.tv_sec * 1000000 + (long)timestamp.tv_usec;
//     int diff = end_ts - signal_ts;
//     total_time += diff;
//     num_profiles++;
//     double percent = 100 * total_time / (num_profiles * interval * 1000.0);

//     cout << "Overhead: " << percent << "%" << endl;
// }
// action that runs when there is a signal
// get tid
// create event info related to tid

void test_thread_time(long ts) {
   gettimeofday(&timestamp, NULL);
   long ts2 = (long)timestamp.tv_sec * 1000000 + (long)timestamp.tv_usec;

   cout << "thread context arrived " << ts2-ts << endl;
}

void Profiling::profiler_record_frames(void *data) {
    PROFILE_FUNCTION();
    // get tid
    pid_t tid = AO_GETTID;

    gettimeofday(&timestamp, NULL);
    long ts = (long)timestamp.tv_sec * 1000000 + (long)timestamp.tv_usec;
    
    // check if this thread is being profiled
    if (prof_data[tid].running_p) {
        // get the frames
        int num = rb_profile_frames(0, sizeof(frames_buffer)/sizeof(VALUE), frames_buffer, lines_buffer);

        if (getenv("AO_PROF_THREAD")) {
            // msg message = { frames_buffer, num, tid, ts, Context::toString() };
            msg message= { {}, num, tid, ts, Context::toString() };
            copy_n(frames_buffer, num, message.frames_buffer);
            
            // TODO check https://www.boost.org/doc/libs/1_72_0/doc/html/lockfree/examples.html
            // why are they doing
            // while (!spsc_queue.push(value))
            // ;
            // that's blocking

            spsc_queue.push(message);
            // std::async(std::launch::async, Profiling::process_snapshot, frames_buffer, num, tid, ts);
        } else {
            Profiling::process_snapshot(frames_buffer, num, tid, ts);
        }
    }

    // add this timestamp as omitted to other running threads that are profiled
    for(pair<const pid_t, frames_struct_t>& ele : prof_data) {
        if (ele.second.running_p && ele.first != tid) {
            ele.second.omitted[ele.second.omitted_num] = ts;
            ele.second.omitted_num++;
        }
    }

}

// preparing a function that could run in a thread
std::mutex pm;

void Profiling::process_snapshot(VALUE *frames_buffer, int num, pid_t tid, long ts) {
    // PROFILE_FUNCTION();
// cout << "running asynch" << endl;

    num = Snapshot::remove_garbage(frames_buffer, num);

    // find the number of matching frames from the top
    int num_match = Snapshot::compare(frames_buffer, num, prof_data[tid].prev_frames_buffer, prof_data[tid].prev_num);
    int num_new = num - num_match;

    int num_exited = prof_data[tid].prev_num - num_match;

    {
        std::lock_guard<std::mutex> guard(pm);

        if (num_new == 0 && num_exited == 0) {
            prof_data[tid].omitted[prof_data[tid].omitted_num] = ts;
            prof_data[tid].omitted_num++;
            prof_data[tid].prev_timestamp = timestamp;
            // calculate_overhead();
            return;
        }

        // // keep until all debugging is done
        // // if (num_new > 0) cout << endl;
        // // cout << "#frames matching: " << num_match
        // //           << " (total: " << num << " new: " << num_new
        // //           << " exited: " << num_exited << ")" << endl;

        for (int i = 0; i < num_new; i++) {
            Frames::extract_frame_info(frames_buffer[i], &new_frames[i]);
            // Frames::print_frame_info(&new_frames[i], i);
        }

        Logging::log_profile_snapshot(prof_data[tid].prof_op_id,
                                      ts,                          // timestamp
                                      new_frames,                  // <vector> new frames
                                      num_new,                     // number of new frames
                                      num_exited,                  // number of exited frames
                                      num,                         // total number of frames
                                      prof_data[tid].omitted,      // array of timestamps of omitted snapshots
                                      prof_data[tid].omitted_num,  // number of omitted snapshots
                                      tid);                        // thread id

        // reset omitted
        // record timestamp, snapshot
        prof_data[tid].omitted_num = 0;
        prof_data[tid].prev_timestamp = timestamp;
        prof_data[tid].prev_num = num;
        for (int i = 0; i < num; ++i)
            prof_data[tid].prev_frames_buffer[i] = frames_buffer[i];
    }
}

void Profiling::profiler_signal_handler(int sigint, siginfo_t *siginfo, void *ucontext) {
    static int in_signal_handler = 0;

    if (in_signal_handler) return;
    if (!running) return;

    in_signal_handler++;
    // gettimeofday(&timestamp, NULL);
    // signal_ts = (long)timestamp.tv_sec * 1000000 + (long)timestamp.tv_usec;
    // if (rb_during_gc()) {
    //     // cout << endl << ".... GC ....   " << to_string(signal_ts).substr(0,16) << endl;
    //     in_gc_p = true;
    // } else {
    //     // cout << endl << "____ NO ____   " << to_string(signal_ts).substr(0,16) << endl;
    //     in_gc_p = false;
    // }
        rb_postponed_job_register_one(0, profiler_record_frames, (void *)0);
    //}
    in_signal_handler--;
}

std::mutex m;

VALUE Profiling::profiling_start(pid_t tid) {
    // cout << "************* starting *************** app_root: " << app_root << " tid " << (long)tid << endl;
    PROFILE_FUNCTION();
    std::lock_guard<std::mutex> guard(m);

    long interval_remote = oboe_get_profiling_interval();
    if (interval_remote != -1) 
        // use remote interval if it's set
        interval = interval_remote;

    // send profile entry event
    Logging::log_profile_entry(prof_data[tid].prof_op_id, tid, interval);

    if (!running) {
        struct sigaction sa;
        struct itimerval timer;

        // TODO figure out the mask and threads thing
        // TODO figure out what happens if there is another thread for the same signal
        // set up signal handler and timer
        sa.sa_sigaction = profiler_signal_handler;
        sa.sa_flags = SA_RESTART | SA_SIGINFO;
        sigemptyset(&sa.sa_mask);
        sigaction(SIGALRM, &sa, NULL);

        timer.it_interval.tv_sec = 0;
        timer.it_interval.tv_usec = interval * 1000;
        timer.it_value = timer.it_interval;
        setitimer(ITIMER_REAL, &timer, 0);
    }

    running++;
    return Qtrue;
}

VALUE Profiling::profiling_stop(pid_t tid) {
    // cout << "--------- stopping ----------" << " tid " << (long)tid << endl;
    {
    PROFILE_FUNCTION();
        std::lock_guard<std::mutex> guard(m);
        if (!running) return Qfalse;

        running--;

        if (!running) {
            // stop timer
            struct sigaction sa;
            struct itimerval timer;

            memset(&timer, 0, sizeof(timer));
            setitimer(ITIMER_REAL, &timer, 0);

            sa.sa_handler = SIG_IGN;
            sa.sa_flags = SA_RESTART;
            sigemptyset(&sa.sa_mask);
            sigaction(SIGALRM, &sa, NULL);
        }
    }

    Logging::log_profile_exit(prof_data[tid].prof_op_id, tid, prof_data[tid].omitted, prof_data[tid].omitted_num);

    prof_data[tid].running_p = false;
 

    return Qtrue;
}

VALUE Profiling::set_interval(int argc, VALUE *argv, VALUE self) {
    if (!(argc == 1 && FIXNUM_P(argv[0]))) return Qfalse;

    interval = FIX2INT(argv[0]);

    return Qtrue;
}

VALUE Profiling::get_interval(VALUE self) {
    return INT2FIX(interval);
}

// VALUE Profiling::set_app_root(int argc, VALUE *argv, VALUE self) {
//     // TODO catch exception when string contains null char
//     app_root = StringValueCStr(argv[0]);
//     // cout << "new path: " << app_root << endl;
//     return Qtrue;
// }

VALUE Profiling::profiling_run(VALUE self) {
    rb_need_block();

    pid_t tid = AO_GETTID;
    // cout << "............. run? ............... app_root: " << app_root << " tid " << (long)tid << endl;

    // [] on an unordered_map creates entry if it doesn't exist
    if (prof_data[tid].running_p) return Qfalse;

    prof_data[tid].running_p = true;
    prof_data[tid].prev_num = 0;
    prof_data[tid].omitted_num = 0;
    
    profiling_start(tid);
    rb_ensure(reinterpret_cast<VALUE (*)(...)>(rb_yield), Qundef,
              reinterpret_cast<VALUE (*)(...)>(profiling_stop), tid);
    return Qtrue;
}

VALUE Profiling::profiling_running_p(VALUE self) {
    return (running == 0) ? Qfalse : Qtrue;
}

static void
stackprof_atfork_prepare(void) {
    cout << "Parent getting ready" << endl;
    struct itimerval timer;
    if (running) {
        memset(&timer, 0, sizeof(timer));
        setitimer(ITIMER_REAL, &timer, 0);
    }
}

static void
stackprof_atfork_parent(void) {
    cout << "Parent let child loose" << endl;
    struct itimerval timer;
    if (running) {
        timer.it_interval.tv_sec = 0;
        timer.it_interval.tv_usec = interval;
        timer.it_value = timer.it_interval;
        setitimer(ITIMER_REAL, &timer, 0);
    }
}

static void
stackprof_atfork_child(void) {
    cout << "A child is born" << endl;
}

void Processing::consumer() {
    msg_t msg;
    bool done = false;

    while (!done) {
        while (!spsc_queue.pop(msg)) {
            // sleep for an interval
            boost::this_thread::sleep(boost::posix_time::milliseconds(interval));
            try {
                boost::this_thread::interruption_point();
            } catch (const boost::thread_interrupted &) {
                // Thread interruption request received, break the loop
                std::cout << "- Snapshot processing thread interrupted. Exiting thread." << std::endl;
                done = true;
            }
        }
        process(msg);
    }

}

void Processing::process(msg_t msg) {
    // TODO: find faster way to pass context
    Context::fromString(msg.xtrace);
    Profiling::process_snapshot(msg.frames_buffer, msg.num, msg.tid, msg.ts);
}

extern "C" void Init_profiling(void) {

    static VALUE rb_mAOProfiler = rb_define_module("AOProfiler");
    rb_define_singleton_method(rb_mAOProfiler, "get_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::get_interval), 0);
    rb_define_singleton_method(rb_mAOProfiler, "set_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::set_interval), -1);
    rb_define_singleton_method(rb_mAOProfiler, "run", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_run), 0);
    rb_define_singleton_method(rb_mAOProfiler, "running?", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_running_p), 0);

    pthread_atfork(stackprof_atfork_prepare, stackprof_atfork_parent, stackprof_atfork_child);

    if (getenv("AO_PROF_THREAD")) {
        boost::thread consumer_thread(Processing::consumer);
    } 

    for (int i = 0; i < BUF_SIZE; i++) rb_gc_mark(frames_buffer[i]);
}

// TODO: How to shut down thread, does it shut down automatically?
