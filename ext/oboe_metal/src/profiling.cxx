// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "profiling.h"
#include "logging.h"

#define BUF_SIZE 2048

static struct timeval timestamp;
static VALUE frames_buffer[BUF_SIZE];
static int lines_buffer[BUF_SIZE];
static int num;
static struct timeval prev_timestamp;
static VALUE prev_frames_buffer[BUF_SIZE];
static int prev_lines_buffer[BUF_SIZE];
static int prev_num;

// need to initialize here, hangs if it is done inside the signal handler
static std::vector<frame_t> new_frames(BUF_SIZE);

long interval = 50000; // in microseconds 

void Profiling::profiler_record_frames(void *data) {
    static int i = 0;
    // std::cout << i++;

    gettimeofday(&timestamp, NULL);
    long delta = (long)timestamp.tv_usec - (long)prev_timestamp.tv_usec;
    std::cout << i++ << " " << delta/1000 << std::endl;

    // num = rb_profile_frames(0, sizeof(frames_buffer) / sizeof(VALUE), frames_buffer, lines_buffer);
    std::vector<long> ommitted(0);

    // get and process frames

    // for (int i = 0; i < num; i++) {
    //     VALUE method = rb_profile_frame_method_name(frames_buffer[i]);
    //     if (RB_TYPE_P(rb_profile_frame_method_name(frames_buffer[i]), T_STRING))
    //         std::cout << "<" << RSTRING_PTR(method) << ">" << std::endl;
    // }

    frame_t fr = {"klass", "method", "file", 123};
    new_frames[0] = fr;

    // static bool once = true;
    // if (once) {
        // std::cout << "snapshot" << std::endl;
        num = 1;
        Logging::log_profile_snapshot((long)timestamp.tv_sec * 1000 + (long)timestamp.tv_usec,
                                      new_frames,
                                      1,
                                      0,
                                      num,
                                      ommitted);
        //     once = false;
        // }

    prev_timestamp = timestamp;
}

void Profiling::profiler_signal_handler(int sigint, siginfo_t *siginfo, void *ucontext) {
    static int in_signal_handler = 0;
     
    if (in_signal_handler) return;

    in_signal_handler++;
    static int i = 0;
    if (rb_during_gc()) {
        std::cout << ".... GC ...." << std::endl;

    } else {
        // Event *event = Logging::startEvent();
        rb_postponed_job_register_one(0, profiler_record_frames, (void *)0);
    }
    in_signal_handler--;
}

VALUE Profiling::profiling_start(VALUE self) {
    struct sigaction sa;
    struct itimerval timer;

    long interval_remote = oboe_get_profiling_interval();
    if (interval_remote != -1) {
        // use remote interval if it's set
        interval = interval_remote * 1000;
    }

    // send profile entry event
    Logging::log_profile_entry(interval);

    // do a bit of something before starting the timer
    // it doesn't seem to go into the block otherwise

    printf("%s\n", "STARTING");

    sa.sa_sigaction = profiler_signal_handler;
    sa.sa_flags = SA_RESTART | SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGALRM, &sa, NULL);

    timer.it_interval.tv_sec = 0;
    timer.it_interval.tv_usec = interval;
    timer.it_value = timer.it_interval;
    setitimer(ITIMER_REAL, &timer, 0);

    return Qtrue;
}

VALUE Profiling::profiling_stop(VALUE self) {
    // stop timer
    struct sigaction sa;
    struct itimerval timer;

    // do a bit of something before starting the timer
    // it doesn't seem to go into the block otherwise
    // rb_eval_string_protect("puts '!!!!!!!!! SHUT UP !!!!!!!!!!!!!!!!!!!!'", NULL);
    printf("\n%s\n", "!!!!!!!!! SHUT UP SHUT UP SHUT UP SHUT UP !!!!!!!!!!!!!!!!!!!!");

    memset(&timer, 0, sizeof(timer));
    setitimer(ITIMER_REAL, &timer, 0);

    sa.sa_handler = SIG_IGN;
    sa.sa_flags = SA_RESTART;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGALRM, &sa, NULL);

    gettimeofday(&timestamp, NULL);
    long ts = (long)timestamp.tv_sec*1000+(long)timestamp.tv_usec;

    std::vector<long> ommitted;
    // ommitted.push_back(ts - 40);
    // ommitted.push_back(ts - 20);
    // ommitted.push_back(ts);
    Logging::log_profile_exit(ommitted);
    return Qtrue;
}

VALUE Profiling::profiling_run(VALUE self) {
    rb_need_block();

    for (int i = 0; i < BUF_SIZE; i++)
        rb_gc_mark(frames_buffer[i]);
    profiling_start(self);
    rb_ensure(reinterpret_cast<VALUE (*)(...)>(rb_yield), Qundef,
              reinterpret_cast<VALUE (*)(...)>(profiling_stop), self);
    return Qtrue;
}

extern "C" void Init_profiling(void) {
    rb_mAOProfiler = rb_define_module("AOProfiler");
    rb_define_singleton_method(rb_mAOProfiler, "run", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_run), 0);
}
