// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef PROFILING_H
#define PROFILING_H

#include <ruby/ruby.h>
#include <ruby/debug.h>

#include <atomic>
#include <signal.h>
#include <mutex>
#include <thread>
#include <unordered_map>
#include <vector>

#include "oboe_api.hpp"

using namespace std;

#define BUF_SIZE 2048

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
    static void send_omitted(pid_t tid, long ts);
};

extern "C" void Init_profiling(void);

#endif // PROFILING_H
