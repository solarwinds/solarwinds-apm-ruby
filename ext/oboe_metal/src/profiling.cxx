// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "profiling.h"

void Profiling::profiler_record_frames() {
    printf("r ");
    // get frames
    // process frames
    // Logging::log_profile_snapshot(long timestamp,
    //                                std::vector<Frame> new_frames,
    //                                int exited_frames,
    //                                int total_frames,
    //                                std::vector<long> ommitted);
}

void Profiling::profiler_signal_handler(int sigint, siginfo_t* siginfo, void* ucontext) {
    static int in_signal_handler = 0;
    if (in_signal_handler) return;
    // if (!_stackprof.running) return;

    in_signal_handler++;
    profiler_record_frames();
    in_signal_handler--;
}

VALUE Profiling::profiling_start(VALUE self) {
    // send profile entry event
    // TODO
    Logging::log_profile_entry();

    // start timer
    struct sigaction sa;
    struct itimerval timer;
    int interval = 20000;  // in microseconds

    // do a bit of something before starting the timer
    // it doesn't seem to go into the block otherwise
    // rb_eval_string_protect("puts 'starting'", NULL);
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

    std::vector<long> ommitted;
    ommitted.push_back(10);
    ommitted.push_back(20);
    ommitted.push_back(30);

    Logging::log_profile_exit(ommitted);
    return Qtrue;
}

VALUE Profiling::profiling_run(VALUE self) {
    rb_need_block();
    profiling_start(self);
    rb_ensure(reinterpret_cast<VALUE (*)(...)>(rb_yield), Qundef,
              reinterpret_cast<VALUE (*)(...)>(profiling_stop), self);
    return Qtrue;
}

extern "C" void Init_profiling(void) {
    rb_mAOProfiler = rb_define_module("AOProfiler");
    rb_define_singleton_method(rb_mAOProfiler, "run", reinterpret_cast<VALUE (*)(...)>(Profiling::profiling_run), 0);
}
