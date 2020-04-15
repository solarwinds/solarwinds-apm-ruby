
#ifndef PROFILING_H
#define PROFILING_H

#include <ruby/ruby.h>
#include <ruby/intern.h>
#include <ruby/debug.h>
#include <signal.h>
#include <sys/time.h>
#include <string>
#include <unordered_map>

using namespace std;

#include "oboe.hpp"

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
    static void profiler_record_frames(void *data);
    static void profiler_ruby_frames(void *data);
    static void profiler_signal_handler(int sigint, siginfo_t* siginfo, void* ucontext);
    static VALUE profiling_start();
    static VALUE profiling_stop();
    static VALUE profiling_run(VALUE self);
    static VALUE profiling_running_p(VALUE self);
    static VALUE get_interval(VALUE self);
    static VALUE set_interval(int argc, VALUE* argv, VALUE self);
    static VALUE set_app_root(int, VALUE*, VALUE);
};

extern "C" void Init_profiling(void);

#endif // PROFILING_H
