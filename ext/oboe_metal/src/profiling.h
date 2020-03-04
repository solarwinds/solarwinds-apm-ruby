#include <ruby/ruby.h>
#include <ruby/intern.h>
#include <signal.h>
#include <sys/time.h>

#include "logging.h"

class Profiling {
   public:
    static void profiler_record_frames();
    static void profiler_signal_handler(int sigint, siginfo_t* siginfo, void* ucontext);
    static VALUE profiling_start(VALUE self);
    static VALUE profiling_stop(VALUE self);
    static VALUE profiling_run(VALUE self);
};

static VALUE rb_mAOProfiler;
extern "C" void Init_profiling(void);
