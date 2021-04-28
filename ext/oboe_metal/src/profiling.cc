// Copyright (c) 2021 SolarWinds, LLC.
// All rights reserved.

#include "profiling.h"

#define TIMER_SIG 64           /* Our timer notification signal */

static atomic_long running;

// need to initialize here, hangs if it is done inside the signal handler
// these are reused for every snapshot
static VALUE frames_buffer[BUF_SIZE];
static int lines_buffer[BUF_SIZE];

static atomic_bool profiling_shutdown{false};
long interval = 10;  // in milliseconds, initializing in case Ruby forgets to
timer_t timerid;

typedef struct prof_data {
    bool running_p = false;
    oboe_metadata_t *md;
    string prof_op_id;
    pid_t tid;

    VALUE prev_frames_buffer[BUF_SIZE];
    int prev_num = 0;
    long omitted[BUF_SIZE];
    int omitted_num = 0;
} prof_data_t;

unordered_map<pid_t, prof_data_t> prof_data_map;

long ts_now() {
    struct timeval tv;

    oboe_gettimeofday(&tv);
    return (long)tv.tv_sec * 1000000 + (long)tv.tv_usec;
}

// try catch block to be used inside functions that return an int
// shuts down profiling and returns -1 on error
int Profiling::try_catch_shutdown(std::function<int()> f, string fun_name) {
    try {
        return f();
    } catch (const std::exception &e) {
        string msg = "Exception in " + fun_name + ", can't recover, profiling shutting down";
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, e.what());
        OBOE_DEBUG_LOG_HIGH(OBOE_MODULE_RUBY, msg.c_str());
        Profiling::shut_down();
        return -1;
    } catch (...) {
        string msg = "Exception in " + fun_name + ", can't recover, profiling shutting down";
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, msg.c_str());
        Profiling::shut_down();
        return -1;
    }
}

void Profiling::profiler_record_frames(void *data) {
    pid_t tid = AO_GETTID;
    long ts = ts_now();

    // check if this thread is being profiled
    if (prof_data_map[tid].running_p) {
        // executes in the same thread as rb_postponed_job was called from

        // get the frames
        // won't overrun frames buffer, because size is set in arg 2
        int num = rb_profile_frames(0, sizeof(frames_buffer) / sizeof(VALUE), frames_buffer, lines_buffer);

        Profiling::process_snapshot(frames_buffer, num, tid, ts);
    }

    // add this timestamp as omitted to other running threads that are profiled
    for (pair<const pid_t, prof_data_t> &ele : prof_data_map) {
        if (ele.second.running_p && ele.first != tid) {
            frames_buffer[0] = PR_OTHER_THREAD;
            Profiling::process_snapshot(frames_buffer, 1, ele.first, ts);
        }
    }
}

void Profiling::profiler_record_gc() {
   pid_t tid = AO_GETTID;
   long ts = ts_now();

    // check if this thread is being profiled
    if (prof_data_map[tid].running_p) {
        frames_buffer[0] = PR_IN_GC;
        Profiling::process_snapshot(frames_buffer, 1, tid, ts);
    }

    // add this timestamp as omitted to other running threads that are profiled
    for (pair<const pid_t, prof_data_t> &ele : prof_data_map) {
        if (ele.second.running_p && ele.first != tid) {
            frames_buffer[0] = PR_OTHER_THREAD;
            Profiling::process_snapshot(frames_buffer, 1, ele.first, ts);
        }
    }
}

void Profiling::send_omitted(pid_t tid, long ts) {
    static vector<FrameData> empty;
    Logging::log_profile_snapshot(prof_data_map[tid].md,
                                  prof_data_map[tid].prof_op_id,
                                  ts,                              // timestamp
                                  empty,                           // <vector> new frames
                                  0,                               // number of exited frames
                                  prof_data_map[tid].prev_num,     // total number of frames
                                  prof_data_map[tid].omitted,      // array of timestamps of omitted snapshots
                                  prof_data_map[tid].omitted_num,  // number of omitted snapshots
                                  tid);                            // thread id

    prof_data_map[tid].omitted_num = 0;
}

void Profiling::process_snapshot(VALUE *frames_buffer, int num, pid_t tid, long ts) {
    int num_new = 0;
    int num_exited = 0;
    vector<FrameData> new_frames;

    num = Frames::remove_garbage(frames_buffer, num);

    // find the number of matching frames from the top
    int num_match = Frames::num_matching(frames_buffer,
                                         num,
                                         prof_data_map[tid].prev_frames_buffer,
                                         prof_data_map[tid].prev_num);
    num_new = num - num_match;

    num_exited = prof_data_map[tid].prev_num - num_match;

    if (num_new == 0 && num_exited == 0) {
        prof_data_map[tid].omitted[prof_data_map[tid].omitted_num] = ts;
        prof_data_map[tid].omitted_num++;

        // the omitted buffer can fill up if the interval is small
        // and the stack doesn't change
        // We need to send a profiling event with the timestamps when it is full
        if (prof_data_map[tid].omitted_num >= BUF_SIZE) {
            Profiling::send_omitted(tid, ts);
        }
        return;
    }

    Frames::collect_frame_data(frames_buffer, num_new, new_frames);

    Logging::log_profile_snapshot(prof_data_map[tid].md,
                                  prof_data_map[tid].prof_op_id,
                                  ts,                              // timestamp
                                  new_frames,                      // <vector> new frames
                                  num_exited,                      // number of exited frames
                                  num,                             // total number of frames
                                  prof_data_map[tid].omitted,      // array of timestamps of omitted snapshots
                                  prof_data_map[tid].omitted_num,  // number of omitted snapshots
                                  tid);                            // thread id

    prof_data_map[tid].omitted_num = 0;
    prof_data_map[tid].prev_num = num;
    for (int i = 0; i < num; ++i)
        prof_data_map[tid].prev_frames_buffer[i] = frames_buffer[i];
}

void Profiling::profiler_job_handler(void *data) {
    static std::atomic_int in_job_handler;

    if (in_job_handler) return;
    in_job_handler++;

    try_catch_shutdown([&]() {
        Profiling::profiler_record_frames(data);
        return 0;  // block needs an int returned
    }, "Profiling::profiler_job_handler()");

    in_job_handler--;
}

void Profiling::profiler_gc_handler(void *data) {
    static std::atomic_int in_gc_handler;
    if (in_gc_handler) return;
    in_gc_handler++;

    try_catch_shutdown([]() {
        Profiling::profiler_record_gc();
        return 0;  // block needs an int returned
    }, "Profiling::profiler_gc_handler()");

    in_gc_handler--;
}

void Profiling::profiler_signal_handler(int sigint, siginfo_t *siginfo, void *ucontext) {
    static std::atomic_int in_signal_handler{0};

    if (in_signal_handler) return;
    in_signal_handler++;

    try_catch_shutdown([]() {
        if (rb_during_gc()) {
            rb_postponed_job_register(0, profiler_gc_handler, (void *)0);
        } else {
            rb_postponed_job_register(0, profiler_job_handler, (void *)0);
        }
        return 0;  // block needs an int returned
    }, "Profiling::profiler_signal_handler()");

    in_signal_handler--;
}

void Profiling::profiling_start(pid_t tid) {
    prof_data_map[tid].md = Context::get();
    prof_data_map[tid].prev_num = 0;
    prof_data_map[tid].omitted_num = 0;
    prof_data_map[tid].running_p = true;

    Logging::log_profile_entry(prof_data_map[tid].md,
                               prof_data_map[tid].prof_op_id,
                               tid,
                               interval);

    if (!running) {
        struct sigaction sa;

        // sa_mask : Additional set of signals to be blocked during execution of signal-catching function
        // what happens if there is another action for the same signal?
        // => last one defined wins!

        // use create_timer created in Init_profiling instead of setitimer
        struct itimerspec ts;

        // TODO does sigaction need to be assigned each time or does it persist?
        sa.sa_sigaction = profiler_signal_handler;
        sa.sa_flags = SA_RESTART | SA_SIGINFO;
        sigemptyset(&sa.sa_mask);
        if (sigaction(TIMER_SIG, &sa, NULL) == -1) {
            OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, "sigaction() failed");
            shut_down();
        }

        /* start timer  */
        ts.it_interval.tv_sec = 0;
        ts.it_interval.tv_nsec = interval * 1000000;
        ts.it_value.tv_sec = 0;
        ts.it_value.tv_nsec = interval * 1000000;

        if (timer_settime(timerid, 0, &ts, NULL) == -1) {
            OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, "timer_settime() failed");
            shut_down();
        }
    }
    running++;
}

VALUE Profiling::profiling_stop(pid_t tid) {
    if (!running) return Qfalse;

    running--;
    int result = try_catch_shutdown([&]() {
        if (!running) {
            // stop the timer, needs both (value and interval) set to 0
            struct itimerspec ts;
            ts.it_value.tv_sec = 0;
            ts.it_value.tv_nsec = 0;
            ts.it_interval.tv_sec = 0;
            ts.it_interval.tv_nsec = 0;

            if (timer_settime(timerid, 0, &ts, NULL) == -1) {
                OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, "timer_settime() failed");
                shut_down();
            }
        }

        Logging::log_profile_exit(prof_data_map[tid].md,
                                  prof_data_map[tid].prof_op_id,
                                  tid,
                                  prof_data_map[tid].omitted,
                                  prof_data_map[tid].omitted_num);

        prof_data_map[tid].running_p = false;
        return 0; // block needs an int returned
    }, "Profiling::profiling_stop()");

    return (result == 0) ? Qtrue : Qfalse;
}

VALUE Profiling::set_interval(VALUE self, VALUE val) {
    if (!FIXNUM_P(val)) return Qfalse;

    interval = FIX2INT(val);

    return Qtrue;
}

VALUE Profiling::get_interval() {
    return INT2FIX(interval);
}

VALUE Profiling::profiling_run(VALUE self, VALUE rb_thread_val) {
    rb_need_block();  // checks if function is called with a block in Ruby
    if (profiling_shutdown) rb_yield(Qundef);

    pid_t tid = AO_GETTID;

    if (prof_data_map[tid].running_p) return Qfalse;
    prof_data_map[tid].omitted_num = 0;

    // !!!!! Can't use try_catch_shutdown() here, causes a memory leak !!!!!
    try {
        profiling_start(tid);
        rb_ensure(reinterpret_cast<VALUE (*)(...)>(rb_yield), Qundef,
                  reinterpret_cast<VALUE (*)(...)>(profiling_stop), tid);
        return Qtrue;
    } catch (const std::exception &e) {
        string msg = "Exception in Profiling::profiling_run, can't recover, profiling shutting down";
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, e.what());
        OBOE_DEBUG_LOG_HIGH(OBOE_MODULE_RUBY, msg.c_str());
        Profiling::shut_down();
        return Qfalse;
    } catch (...) {
        string msg = "Exception in Profiling::profiling_run, can't recover, profiling shutting down";
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, msg.c_str());
        Profiling::shut_down();
        return Qfalse;
    }

    return Qfalse;
}

// in case C++ misbehaves we will stop profiling
// to be used when catching exceptions
void Profiling::shut_down() {
    static bool started = false;
    // stop all profiling, the last one also stops the timer/signals
    if (!started) {
        for (pair<const pid_t, prof_data_t> &ele : prof_data_map) {
            started = true;
            profiling_stop(ele.first);
        }
    }
    // avoid running any more profiling
    profiling_shutdown = true;
}

VALUE Profiling::getTid() {
    pid_t tid = AO_GETTID;

    return INT2NUM(tid);
}

static void
prof_atfork_prepare(void) {
    // cout << "Parent getting ready" << endl;
}

static void
prof_atfork_parent(void) {
    // cout << "Parent let child loose" << endl;
}

// make sure new processes have a clean slate for profiling
static void
prof_atfork_child(void) {
    // cout << "A child is born" << endl;
    Frames::clear_cached_frames();
    prof_data_map.clear();
    running = false;

    // make sure it has a timer ready, it is a per-process-timer
    Profiling::create_timer();
}

void Profiling::create_timer() {
    struct sigevent sev;

    sev.sigev_value.sival_ptr = &timerid;
    sev.sigev_notify = SIGEV_SIGNAL; /* Notify via signal */
    sev.sigev_signo = SIGRTMAX;      /* Notify using this signal */

    if (timer_create(CLOCK_REALTIME, &sev, &timerid) == -1) {
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, "timer_create() failed");
        profiling_shutdown = true;  // no profiling without clock
    }
}

extern "C" void Init_profiling(void) {
    Profiling::create_timer();
    Frames::reserve_cached_frames();

    // creates Ruby Module: AppOpticsAPM::CProfiler
    static VALUE rb_mAppOpticsAPM = rb_define_module("AppOpticsAPM");
    static VALUE rb_mCProfiler = rb_define_module_under(rb_mAppOpticsAPM, "CProfiler");

    rb_define_singleton_method(rb_mCProfiler, "get_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::get_interval), 0);
    rb_define_singleton_method(rb_mCProfiler, "set_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::set_interval), 1);
    rb_define_singleton_method(rb_mCProfiler, "run", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_run), 1);
    rb_define_singleton_method(rb_mCProfiler, "get_tid", reinterpret_cast<VALUE (*)(...)>(Profiling::getTid), 0);

    pthread_atfork(prof_atfork_prepare,
                   prof_atfork_parent,
                   prof_atfork_child);

    // TODO better understand the gc marking
    // ____ needed???
    // ____ does it last forever or is it reset after a gc?
    for (int i = 0; i < BUF_SIZE; i++) rb_gc_mark(frames_buffer[i]);
}
