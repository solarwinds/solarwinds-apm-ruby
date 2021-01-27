// Copyright (c) 2021 SolarWinds, LLC.
// All rights reserved.

#ifndef PROFILING_H
#define PROFILING_H

#include <signal.h>

#include <ruby/ruby.h>

using namespace std;

#define BUF_SIZE 2048

// these definitions are based on the assumption that there are no
// frames with VALUE == 1 or VALUE == 2 in Ruby
// profiling wont blow up if there are, because there is also a check to see
// if the stack has size == 1 when assuming these frames
#define PR_OTHER_THREAD 1
#define PR_IN_GC 2

#if !defined(AO_GETTID)
     #if defined(_WIN32)
        #define AO_GETTID GetCurrentThreadId
     #else
        #include <unistd.h>
        #include <sys/syscall.h>
        #ifdef SYS_gettid
           #define AO_GETTID syscall(SYS_gettid);
        #endif
     #endif
#endif


class Profiling {
   public:
    // These are available in Ruby
    static VALUE profiling_run(VALUE self, VALUE rb_thread_val);
    static VALUE get_interval();
    static VALUE set_interval(VALUE self, VALUE interval);
    static VALUE getTid();

    // This is used via rb_ensure and needs VALUE as a return type
    static VALUE profiling_stop(pid_t tid);

    // These are used within the c++ code only
    static void profiling_start(pid_t tid);

    static void profiler_signal_handler(int sigint,
                                        siginfo_t* siginfo,
                                        void* ucontext);
    static void profiler_job_handler(void* data);
    static void process_snapshot(VALUE* frames_buffer,
                                 int num,
                                 pid_t tid,
                                 long ts);
    static void profiler_record_frames(void *data);
    static void profiler_record_gc();
    static void send_omitted(pid_t tid, long ts);
};

extern "C" void Init_profiling(void);

#endif // PROFILING_H
