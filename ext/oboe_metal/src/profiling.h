
#ifndef PROFILING_H
#define PROFILING_H

#include <ruby/ruby.h>
#include <ruby/intern.h>
#include <ruby/debug.h>
#include <signal.h>
#include <sys/time.h>
#include <string>

typedef struct frame_info {
    std::string klass;
    std::string method;
    std::string file;
    int lineno;
} frame_t;

class Profiling {
   public:
    static void profiler_record_frames(void *data);
    static void profiler_signal_handler(int sigint, siginfo_t* siginfo, void* ucontext);
    static VALUE profiling_start(VALUE self);
    static VALUE profiling_stop(VALUE self);
    static VALUE profiling_run(VALUE self);
};

static VALUE rb_mAOProfiler;
extern "C" void Init_profiling(void);

#endif // PROFILING_H
