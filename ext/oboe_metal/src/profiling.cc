// Copyright (c) 2021 SolarWinds, LLC.
// All rights reserved.

#include "profiling.h"

#include <ruby/debug.h>
#include <signal.h>
#include <time.h>

#include <atomic>
#include <unordered_map>
#include <vector>

#include "frames.h"
#include "logging.h"
#include "oboe_api.hpp"


#define TIMER_SIG SIGRTMAX        // the timer notification signal

using namespace std;

static atomic_bool running;
atomic_bool profiling_shut_down;  // !! can't be static because of tests

// need to initialize here, hangs if it is done inside the signal handler
// these are reused for every snapshot
static VALUE frames_buffer[BUF_SIZE];
static int lines_buffer[BUF_SIZE];


static long configured_interval = 10;  // in milliseconds, initializing in case Ruby forgets to
static long current_interval = 10;
timer_t timerid;

typedef struct prof_data {
    bool running_p = false;
    Metadata md = Metadata(Context::get());
    string prof_op_id;

    VALUE prev_frames_buffer[BUF_SIZE];
    int prev_num = 0;
    long omitted[BUF_SIZE];
    int omitted_num = 0;
} prof_data_t;

unordered_map<pid_t, prof_data_t> prof_data_map;

const string Profiling::string_job_handler = "Profiling::profiler_job_handler()";
const string Profiling::string_gc_handler = "Profiling::profiler_gc_handler()";
const string Profiling::string_signal_handler = "Profiling::profiler_signal_handler()";
const string Profiling::string_stop = "Profiling::profiling_stop()";

// for debugging only
void print_prof_data_map() {
    pid_t tid = AO_GETTID;
    Metadata md_str(prof_data_map[tid].md);
    cout << tid << ", " << prof_data_map[tid].running_p << ", " << prof_data_map[tid].prof_op_id << ", ";
    cout << md_str.toString() << ", " << prof_data_map[tid].prev_num << ", " << prof_data_map[tid].omitted_num << endl;
}

long ts_now() {
    struct timeval tv;

    oboe_gettimeofday(&tv);
    return (long)tv.tv_sec * 1000000 + (long)tv.tv_usec;
}

// try catch block to be used inside functions that return an int
// shuts down profiling and returns -1 on error
int Profiling::try_catch_shutdown(std::function<int()> f, const string& fun_name) {
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

void Profiling::profiler_record_frames() {
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
    static atomic_bool in_job_handler{false};

    // atomically replaces the value of the object, returns the value held previously
    if (in_job_handler.exchange(true)) return;

    try_catch_shutdown([&]() {
        Profiling::profiler_record_frames();
        return 0;  // block needs an int returned
    }, Profiling::string_job_handler);

    in_job_handler = false;
}

void Profiling::profiler_gc_handler(void *data) {
    static atomic_bool in_gc_handler{false};

    // atomically replaces the value of the object, returns the value held previously
    if (in_gc_handler.exchange(true)) return;

    try_catch_shutdown([]() {
        Profiling::profiler_record_gc();
        return 0;  // block needs an int returned
    }, Profiling::string_gc_handler);

    in_gc_handler = false;
}

////////////////////////////////////////////////////////////////////////////////
// THIS IS THE SIGNAL HANDLER FUNCTION
// ONLY ASYNC-SAFE FUNCTIONS ALLOWED IN HERE (no exception handling !!!)
////////////////////////////////////////////////////////////////////////////////
extern "C" void profiler_signal_handler(int sigint, siginfo_t *siginfo, void *ucontext) {
    static std::atomic_bool in_signal_handler{false};

    // atomically replaces the value of the object, returns the value held previously
    // also keeps in_signal_handler lock_free -> asyn-safe
    if (in_signal_handler.exchange(true)) return;

    // the following two ruby c-functions are asyn safe
    if (rb_during_gc())
    {
        rb_postponed_job_register(0, Profiling::profiler_gc_handler, (void *)0);
    } else {
        rb_postponed_job_register(0, Profiling::profiler_job_handler, (void *)0);
    }

    in_signal_handler = false;
}

void Profiling::profiling_start(pid_t tid) {
    prof_data_map[tid].md = Metadata(Context::get());
    prof_data_map[tid].prev_num = 0;
    prof_data_map[tid].omitted_num = 0;
    prof_data_map[tid].running_p = true;

    Logging::log_profile_entry(prof_data_map[tid].md,
                               prof_data_map[tid].prof_op_id,
                               tid,
                               current_interval);

    if (!running.exchange(true)) {
        // start timer with interval timer spec
        struct itimerspec ts;
        ts.it_interval.tv_sec = 0;
        ts.it_interval.tv_nsec = current_interval * 1000000;
        ts.it_value.tv_sec = 0;
        ts.it_value.tv_nsec = ts.it_interval.tv_nsec;

        // global timer_t timerid points to timer created in Init_profiling
        if (timer_settime(timerid, 0, &ts, NULL) == -1) {
            OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, "timer_settime() failed");
            shut_down();
        }
    }
}

VALUE Profiling::profiling_stop(pid_t tid) {
    if (!running.exchange(false)) return Qfalse;

    int result = try_catch_shutdown([&]() {
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

        Logging::log_profile_exit(prof_data_map[tid].md,
                                  prof_data_map[tid].prof_op_id,
                                  tid,
                                  prof_data_map[tid].omitted,
                                  prof_data_map[tid].omitted_num);

        prof_data_map[tid].running_p = false;
        return 0; // block needs an int returned
    }, Profiling::string_stop);

    return (result == 0) ? Qtrue : Qfalse;
}

VALUE Profiling::set_interval(VALUE self, VALUE val) {
    if (!FIXNUM_P(val)) return Qfalse;

    configured_interval = FIX2INT(val);

    return Qtrue;
}

VALUE Profiling::get_interval() {
    return INT2FIX(current_interval);
}

VALUE Profiling::profiling_run(VALUE self, VALUE rb_thread_val, VALUE interval) {
    rb_need_block();  // checks if function is called with a block in Ruby
    if (profiling_shut_down || OboeProfiling::get_interval() == 0) {
        return rb_yield(Qundef);
    }

    if (FIXNUM_P(interval)) configured_interval = FIX2INT(interval);
    current_interval = max(configured_interval, (long)OboeProfiling::get_interval());

    // !!!!! Can't use try_catch_shutdown() here, MAKES rb_ensure cause a memory leak !!!!!
    try {
        pid_t tid = AO_GETTID;
        profiling_start(tid);
        rb_ensure(reinterpret_cast<VALUE (*)(...)>(rb_yield), Qundef,
                  reinterpret_cast<VALUE (*)(...)>(profiling_stop), tid);
        return Qtrue;
    } catch (const std::exception &e) {
        string msg = "Exception in Profiling::profiling_run(), can't recover, profiling shutting down";
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, e.what());
        OBOE_DEBUG_LOG_HIGH(OBOE_MODULE_RUBY, msg.c_str());
        shut_down();
        return Qfalse;
    } catch (...) {
        string msg = "Exception in Profiling::profiling_run(), can't recover, profiling shutting down";
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, msg.c_str());
        shut_down();
        return Qfalse;
    }

    return Qfalse;
}

// in case C++ misbehaves we will stop profiling
// to be used when catching exceptions
void Profiling::shut_down() {
    static atomic_bool ending{false};

    if (ending.exchange(true)) return;

    // avoid running any more profiling
    profiling_shut_down = true;

    // stop all profiling, the last one also stops the timer/signals
    for (pair<const pid_t, prof_data_t> &ele : prof_data_map) {
        profiling_stop(ele.first);
    }
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

void Profiling::create_sigaction() {
    struct sigaction sa;
    // what happens if there is another action for the same signal?
    // => last one defined wins!
    sa.sa_sigaction = profiler_signal_handler;
    sa.sa_flags = SA_RESTART | SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    if (sigaction(TIMER_SIG, &sa, NULL) == -1) {
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, "sigaction() failed");
        profiling_shut_down = true;  // no profiling without sigaction
    }
}

void Profiling::create_timer() {
    struct sigevent sev;

    sev.sigev_value.sival_ptr = &timerid;
    sev.sigev_notify = SIGEV_SIGNAL; /* Notify via signal */
    sev.sigev_signo = SIGRTMAX;      /* Notify using this signal */

    if (timer_create(CLOCK_REALTIME, &sev, &timerid) == -1) {
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_RUBY, "timer_create() failed");
        profiling_shut_down = true;  // no profiling without clock
    }
}

extern "C" void Init_profiling(void) {
    // assign values to global atomic vars that know about state of profiling
    running = false;
    profiling_shut_down = false;

    // prep data structures
    Profiling::create_sigaction();
    Profiling::create_timer();
    Frames::reserve_cached_frames();

    // create Ruby Module: AppOpticsAPM::CProfiler
    static VALUE rb_mAppOpticsAPM = rb_define_module("AppOpticsAPM");
    static VALUE rb_mCProfiler = rb_define_module_under(rb_mAppOpticsAPM, "CProfiler");

    rb_define_singleton_method(rb_mCProfiler, "get_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::get_interval), 0);
    rb_define_singleton_method(rb_mCProfiler, "set_interval", reinterpret_cast<VALUE (*)(...)>(Profiling::set_interval), 1);
    rb_define_singleton_method(rb_mCProfiler, "run", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_run), 2);
    rb_define_singleton_method(rb_mCProfiler, "get_tid", reinterpret_cast<VALUE (*)(...)>(Profiling::getTid), 0);

    pthread_atfork(prof_atfork_prepare,
                   prof_atfork_parent,
                   prof_atfork_child);
}
