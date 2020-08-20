// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef PROFILING_V2_H
#define PROFILING_V2_H

#include <ruby/ruby.h>
#include <ruby/debug.h>

#include <signal.h>
#include <mutex>
#include <atomic>
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

class Profiling_V2 {
   public:
    static VALUE profiling_run(VALUE self, VALUE rb_thread_val);
    static VALUE set_interval(VALUE self, VALUE interval);
    static VALUE getTid();
};

extern "C" void Init_profiling_V2(void);

#endif // PROFILING_V2_H
