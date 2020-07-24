// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

// #include <malloc.h>
#include <atomic>

#include "profiling.h"
#include "logging.h"
#include "frames.h"


std::atomic_long running;

typedef struct frames_struct {
    bool running_p = false;
    uint8_t prof_op_id[OBOE_MAX_OP_ID_LEN];
    Metadata* md = NULL;

    struct timeval prev_timestamp;
    VALUE prev_frames_buffer[BUF_SIZE];
    int prev_num = 0;
    long omitted[BUF_SIZE];
    int omitted_num = 0;
} frames_struct_t;

std::unordered_map<pid_t, frames_struct_t> prof_data;
std::mutex pd_mutex;

static struct timeval timestamp;
// need to initialize here, hangs if it is done inside the signal handler
static VALUE frames_buffer[BUF_SIZE];
static int lines_buffer[BUF_SIZE];
static vector<FrameData> new_frames(BUF_SIZE);

long interval = 10;  // in milliseconds, initializing in case ruby forgets to

static bool running_p(pid_t tid) {
    std::lock_guard<std::mutex> guard(pd_mutex);
    return prof_data[tid].running_p;
}

// TODO maybe use std::async for some stuff that doesn't read the frame info from Ruby
void Profiling::profiler_record_frames(void *data) {
    pid_t tid = AO_GETTID;

    gettimeofday(&timestamp, NULL);
    long ts = (long)timestamp.tv_sec * 1000000 + (long)timestamp.tv_usec;

    // check if this thread is being profiled
    // doing it here, because I'm not sure if a postponed job executes in the 
    // same thread as rb_postponed_job was called from
    if (running_p(tid)) {
        // get the frames
        int num = rb_profile_frames(0, sizeof(frames_buffer) / sizeof(VALUE), frames_buffer, lines_buffer);
        Profiling::process_snapshot(frames_buffer, num, tid, ts);
    }

    // add this timestamp as omitted to other running threads that are profiled
    if (std::getenv("AO_ADD_OMITTED")) {
        {
            std::lock_guard<std::mutex> guard(pd_mutex);
            for (pair<const pid_t, frames_struct_t> &ele : prof_data) {
                if (ele.second.running_p && ele.first != tid) {
                    ele.second.omitted[ele.second.omitted_num] = ts;
                    ele.second.omitted_num++;
                    if (ele.second.omitted_num >= BUF_SIZE) {
                        Profiling::send_omitted(ele.first, ts, ele.second.md);
                        ele.second.omitted_num = 0;
                    }
                }
            }
        }
    }
}

void Profiling::send_omitted(pid_t tid, long ts, Metadata *md) {
    oboe_metadata_t *local_md;
    bool valid_context = false;
    if (md != NULL) {
        local_md = Context::get();
        valid_context = Context::isValid(); 

        // switch context
        Context::set(md);
    }

    {
        std::lock_guard<std::mutex> guard(pd_mutex);
        Logging::log_profile_snapshot(prof_data[tid].prof_op_id,
                                      ts,                          // timestamp
                                      new_frames,                  // <vector> new frames
                                      0,                           // number of new frames
                                      0,                           // number of exited frames
                                      prof_data[tid].prev_num,     // total number of frames
                                      prof_data[tid].omitted,      // array of timestamps of omitted snapshots
                                      prof_data[tid].omitted_num,  // number of omitted snapshots
                                      tid);                        // thread id

        if (md != NULL) {
            if (valid_context)
                Context::set(local_md);
            else
                Context::clear();
        }

        prof_data[tid].omitted_num = 0;
    }
}

void Profiling::process_snapshot(VALUE *frames_buffer, int num, pid_t tid, long ts) {
    int num_new = 0;
    int num_exited = 0;
    num = Snapshot::remove_garbage(frames_buffer, num);

    {
        std::lock_guard<std::mutex> guard(pd_mutex);
        // find the number of matching frames from the top
        int num_match = Snapshot::compare(frames_buffer, num, prof_data[tid].prev_frames_buffer, prof_data[tid].prev_num);
        num_new = num - num_match;

        num_exited = prof_data[tid].prev_num - num_match;

        if (num_new == 0 && num_exited == 0) {
            prof_data[tid].omitted[prof_data[tid].omitted_num] = ts;
            prof_data[tid].omitted_num++;
            prof_data[tid].prev_timestamp = timestamp;
            // the omitted buffer can fill up if there is another thread
            // running that is taking up a lot of time.
            // We need to send a profiling event when it is full
            if (prof_data[tid].omitted_num >= BUF_SIZE) {
                std::cout << "=== Buffer full! ===" << std::endl;
                Profiling::send_omitted(tid, ts);
            }
            return;
        }
    }

    for (int i = 0; i < num_new; i++) {
        Frames::extract_frame_info(frames_buffer[i], &new_frames[i]);
    }

    {
        std::lock_guard<std::mutex> guard(pd_mutex);
        Logging::log_profile_snapshot(prof_data[tid].prof_op_id,
                                      ts,                          // timestamp
                                      new_frames,                  // <vector> new frames
                                      num_new,                     // number of new frames
                                      num_exited,                  // number of exited frames
                                      num,                         // total number of frames
                                      prof_data[tid].omitted,      // array of timestamps of omitted snapshots
                                      prof_data[tid].omitted_num,  // number of omitted snapshots
                                      tid);                        // thread id

        prof_data[tid].omitted_num = 0;
        prof_data[tid].prev_timestamp = timestamp;
        prof_data[tid].prev_num = num;
        for (int i = 0; i < num; ++i)
            prof_data[tid].prev_frames_buffer[i] = frames_buffer[i];
    }
}

static void profiler_job_handler(void *data) {
    static std::atomic_int in_job_handler;
    if (in_job_handler) return;
    if (!running) return;

    in_job_handler++;
    Profiling::profiler_record_frames(data);
    in_job_handler--;
}

void Profiling::profiler_signal_handler(int sigint, siginfo_t *siginfo, void *ucontext) {
    static std::atomic_int in_signal_handler;

    if (in_signal_handler) return;
    if (!running) return;

    in_signal_handler++;
    rb_postponed_job_register_one(0, profiler_job_handler, (void *)0);
    in_signal_handler--;
}

VALUE Profiling::profiling_start(pid_t tid) {

    long interval_remote = oboe_get_profiling_interval();
    if (interval_remote != -1)
        interval = interval_remote;

    Logging::log_profile_entry(prof_data[tid].prof_op_id, tid, interval);
    
    {
        std::lock_guard<std::mutex> guard(pd_mutex);
        delete prof_data[tid].md;
        prof_data[tid].md = Context::copy();
    }

    if (!running) {
        // the signal is sent to all threads, 
        // timer/signal may already be running
        struct sigaction sa;
        struct itimerval timer;

        // TODO figure out the mask and threads thing
        // TODO figure out what happens if there is another action for the same signal
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
    if (!running) return Qfalse;

    running--;

    if (!running) {
        // no threads are profiling -> stop global timer/signal
        struct sigaction sa;
        struct itimerval timer;

        memset(&timer, 0, sizeof(timer));
        setitimer(ITIMER_REAL, &timer, 0);

        sa.sa_handler = SIG_IGN;
        sa.sa_flags = SA_RESTART;
        sigemptyset(&sa.sa_mask);
        sigaction(SIGALRM, &sa, NULL);
    }

    Logging::log_profile_exit(prof_data[tid].prof_op_id, tid, prof_data[tid].omitted, prof_data[tid].omitted_num);

    {
        std::lock_guard<std::mutex> guard(pd_mutex);
        // TODO refactor once there is a bg cleanup thread for prof_data
        prof_data[tid].running_p = false;
        delete prof_data[tid].md;
        prof_data.erase(tid);
    }

    return Qtrue;
}

VALUE Profiling::set_interval(int interval) {
    if (!FIXNUM_P(interval)) return Qfalse;

    interval = FIX2INT(interval);

    return Qtrue;
}

VALUE Profiling::get_interval() {
    return INT2FIX(interval);
}

VALUE Profiling::profiling_run() {
    rb_need_block(); // checks if function is called with a block in Ruby

    pid_t tid = AO_GETTID;
    {
        std::lock_guard<std::mutex> guard(pd_mutex);
        if (prof_data[tid].running_p) return Qfalse;
        prof_data[tid].running_p = true;
        prof_data[tid].omitted_num = 0;
    }
        
    profiling_start(tid);
    rb_ensure(reinterpret_cast<VALUE (*)(...)>(rb_yield), Qundef,
              reinterpret_cast<VALUE (*)(...)>(profiling_stop), tid);

    return Qtrue;
}

VALUE Profiling::profiling_running_p() {
    return running ? Qtrue : Qfalse;
}


VALUE Profiling::getTid() {
    pid_t tid = AO_GETTID;

    return INT2NUM(tid);
}

void cleanup_prof_data() {
    while(true) {
        // find currently running thread id
        // foreach key in prof_data
           // if not in current_tids
                // prof_data.erase(key);
        sleep(60);
    }
}

static void
stackprof_atfork_prepare(void) {
    // cout << "Parent getting ready" << endl;
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

extern "C" void Init_profiling(void) {
    cout << "Initializing Profiling" << endl;
    static VALUE rb_mAOProfiler = rb_define_module("AOProfiler");
    rb_define_singleton_method(rb_mAOProfiler, "get_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::get_interval), 0);
    rb_define_singleton_method(rb_mAOProfiler, "set_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::set_interval), -1);
    rb_define_singleton_method(rb_mAOProfiler, "run", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_run), 0);
    rb_define_singleton_method(rb_mAOProfiler, "running?", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_running_p), 0);
    rb_define_singleton_method(rb_mAOProfiler, "getTid", reinterpret_cast<VALUE (*)(...)>(Profiling::getTid), 0);

    // TODO better understand pthread_atfork
    pthread_atfork(stackprof_atfork_prepare,
                   stackprof_atfork_parent,
                   stackprof_atfork_child);

    // TODO better understand the gc marking
    // ____ does it last forever or is it reset after a gc?
    for (int i = 0; i < BUF_SIZE; i++) rb_gc_mark(frames_buffer[i]); 

    // TODO start *detached* bg thread that cleans up prof_data every 5(?) minutes
    // ____ if prof_data.size() > 200(?)
    // ____ remove prof_data entries not in `ls /proc/$pid/task`
}

