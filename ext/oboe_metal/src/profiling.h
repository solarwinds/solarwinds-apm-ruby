// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef PROFILING_H
#define PROFILING_H

#include <ruby/ruby.h>
#include <ruby/debug.h>

#include <signal.h>
#include <mutex>
#include <thread>
#include <unordered_map>

#include "oboe.hpp"

#define BUF_SIZE 2048

using namespace std;

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
    static VALUE profiling_run(VALUE self, VALUE rb_thread_val);
    static VALUE profiling_running_p();
    static VALUE get_interval();
    static VALUE set_interval(int interval);
    static VALUE getTid();
#ifndef SWIG
    static VALUE profiling_start(pid_t tid);
    static VALUE profiling_stop(pid_t tid);
    static void profiler_signal_handler(int sigint,
                                        siginfo_t* siginfo,
                                        void* ucontext);
    static void process_snapshot(VALUE* frames_buffer,
                                 int num,
                                 pid_t tid,
                                 long ts);
    static void profiler_record_frames(void *data);
    static void send_omitted(pid_t tid, long ts);
#endif
};

extern "C" void Init_profiling(void);

#endif // PROFILING_H
