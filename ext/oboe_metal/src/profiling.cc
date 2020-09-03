// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include <ruby/ruby.h>
#include <ruby/debug.h>

#include <signal.h>
#include <mutex>
#include <thread>
#include <unordered_map>

#include "oboe.hpp"

#include "profiling.h"
#include "logging.h"
#include "frames.h"

atomic_long running;

// need to initialize here, hangs if it is done inside the signal handler
// these are reused for every snapshot
static struct timeval timestamp;
static VALUE frames_buffer[BUF_SIZE];
static int lines_buffer[BUF_SIZE];
static vector<FrameData> new_frames(BUF_SIZE);

long interval = 10;  // in milliseconds, initializing in case Ruby forgets to
// long interval;  // in milliseconds

thread_local struct prof_data {
    bool running = false;
    uint8_t prof_op_id[OBOE_MAX_OP_ID_LEN];

    struct timeval prev_timestamp;
    VALUE prev_frames_buffer[BUF_SIZE];
    int prev_num = 0;
    long omitted[BUF_SIZE];
    int omitted_num = 0;
} th_prof_data;

// TODO maybe use std::async for some stuff that doesn't read the frame info from Ruby
void Profiling::profiler_record_frames(void *data) {
    // check if this thread is being profiled
    // doing it here, because I'm not sure if a postponed job executes in the
    if (!th_prof_data.running) return;

    pid_t tid = AO_GETTID;

    gettimeofday(&timestamp, NULL);
    long ts = (long)timestamp.tv_sec * 1000000 + (long)timestamp.tv_usec;

    // exectues in the same thread as rb_postponed_job was called from
    // get the frames
    // won't overrun frames buffer, because size is set in arg 2
    int num = rb_profile_frames(0, sizeof(frames_buffer) / sizeof(VALUE), frames_buffer, lines_buffer);

    Profiling::process_snapshot(frames_buffer, num, tid, ts);
}

void Profiling::send_omitted(pid_t tid, long ts) {
    Logging::log_profile_snapshot(th_prof_data.prof_op_id,
                                  ts,                        // timestamp
                                  new_frames,                // <vector> new frames
                                  0,                         // number of new frames
                                  0,                         // number of exited frames
                                  th_prof_data.prev_num,     // total number of frames
                                  th_prof_data.omitted,      // array of timestamps of omitted snapshots
                                  th_prof_data.omitted_num,  // number of omitted snapshots
                                  tid);                      // thread id

    th_prof_data.omitted_num = 0;
}

void Profiling::process_snapshot(VALUE *frames_buffer, int num, pid_t tid, long ts) {
    int num_new = 0;
    int num_exited = 0;
    num = Frames::remove_garbage(frames_buffer, num);

    // find the number of matching frames from the top
    int num_match = Frames::num_matching(frames_buffer,
                                      num,
                                      th_prof_data.prev_frames_buffer,
                                      th_prof_data.prev_num);
    num_new = num - num_match;

    num_exited = th_prof_data.prev_num - num_match;

    if (num_new == 0 && num_exited == 0) {
        th_prof_data.omitted[th_prof_data.omitted_num] = ts;
        th_prof_data.omitted_num++;
        th_prof_data.prev_timestamp = timestamp;

        // the omitted buffer can fill up if the interval is small
        // and the stack doesn't change 
        // We need to send a profiling event with the timestamps when it is full
        if (th_prof_data.omitted_num >= BUF_SIZE) {
            Profiling::send_omitted(tid, ts);
        }
        return;
    }

    for (int i = 0; i < num_new; i++) {
        Frames::extract_frame_info(frames_buffer[i], &new_frames[i]);
    }

    Logging::log_profile_snapshot(th_prof_data.prof_op_id,
                                  ts,                        // timestamp
                                  new_frames,                // <vector> new frames
                                  num_new,                   // number of new frames
                                  num_exited,                // number of exited frames
                                  num,                       // total number of frames
                                  th_prof_data.omitted,      // array of timestamps of omitted snapshots
                                  th_prof_data.omitted_num,  // number of omitted snapshots
                                  tid);                      // thread id

    th_prof_data.omitted_num = 0;
    th_prof_data.prev_timestamp = timestamp;
    th_prof_data.prev_num = num;
    for (int i = 0; i < num; ++i)
        th_prof_data.prev_frames_buffer[i] = frames_buffer[i];
}

void Profiling::profiler_job_handler(void *data) {
    static std::atomic_int in_job_handler;
    
    if (in_job_handler) return;
    if (!running || !th_prof_data.running) return;

    in_job_handler++;
    Profiling::profiler_record_frames(data);
    in_job_handler--;
}

void Profiling::profiler_signal_handler(int sigint, siginfo_t *siginfo, void *ucontext) {
    static std::atomic_int in_signal_handler{0};

    if (in_signal_handler) return;
    if (!running) return;

    in_signal_handler++;
    rb_postponed_job_register_one(0, profiler_job_handler, (void *)0);
    // TODO how can I *ensure* this gets reset?
    in_signal_handler--;
}

void Profiling::profiling_start(pid_t tid) {

    Logging::log_profile_entry(th_prof_data.prof_op_id, tid, interval);
    th_prof_data.prev_num = 0;
    th_prof_data.omitted_num = 0;
    th_prof_data.running = true;

    if (!running) {
        // the signal is sent to the process and then one thread,
        // timer/signal may already be running
        struct sigaction sa;
        struct itimerval timer;

        // TODO figure out the mask and threads thing
        // TODO figure out what happens if there is another action for the same signal
        // => last one defined wins!
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

    // return Qtrue;
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

    Logging::log_profile_exit(th_prof_data.prof_op_id, tid, th_prof_data.omitted, th_prof_data.omitted_num);

    th_prof_data.running = false;

    return Qtrue;
}

VALUE Profiling::set_interval(VALUE self, VALUE val) {
    if (!FIXNUM_P(val)) return Qfalse;

    interval = FIX2INT(val);
    // cout << "--- Profiling interval set to " << interval << endl;
    return Qtrue;
}

VALUE Profiling::get_interval() {
    return INT2FIX(interval);
}

VALUE Profiling::profiling_run(VALUE self, VALUE rb_thread_val) {
    rb_need_block(); // checks if function is called with a block in Ruby

    pid_t tid = AO_GETTID;

    if (th_prof_data.running) return Qfalse;
    th_prof_data.omitted_num = 0;

    profiling_start(tid);
    rb_ensure(reinterpret_cast<VALUE (*)(...)>(rb_yield), Qundef,
              reinterpret_cast<VALUE (*)(...)>(profiling_stop), tid);

    return Qtrue;
}

VALUE Profiling::getTid() {
    pid_t tid = AO_GETTID;

    return INT2NUM(tid);
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
    // cout << "Parent let child loose" << endl;
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
    // cout << "A child is born" << endl;
}

extern "C" void Init_profiling(void) {
    // creates Ruby Module: AppOpticsAPM::CProfiler
    static VALUE rb_mAppOpticsAPM = rb_define_module("AppOpticsAPM");
    static VALUE rb_mCProfiler = rb_define_module_under(rb_mAppOpticsAPM, "CProfiler");

    rb_define_singleton_method(rb_mCProfiler, "get_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::get_interval), 0);
    rb_define_singleton_method(rb_mCProfiler, "set_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::set_interval), 1);
    rb_define_singleton_method(rb_mCProfiler, "run", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_run), 1);
    rb_define_singleton_method(rb_mCProfiler, "get_tid", reinterpret_cast<VALUE (*)(...)>(Profiling::getTid), 0);

    // TODO better understand pthread_atfork
    pthread_atfork(stackprof_atfork_prepare,
                   stackprof_atfork_parent,
                   stackprof_atfork_child);

    // TODO better understand the gc marking
    // ____ does it last forever or is it reset after a gc?
    for (int i = 0; i < BUF_SIZE; i++) rb_gc_mark(frames_buffer[i]);
}

