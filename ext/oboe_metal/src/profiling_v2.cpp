// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "readerwriterqueue.h"
#include "profiling_v2.h"
#include "logging_v2.h"
#include "frames_v2.h"
#include <future>

using namespace moodycamel;

long interval_v2 = 10;  // in milliseconds, initializing in case ruby forgets to
atomic_int running_count(0);

typedef struct {
    bool running_p = false;
    VALUE ruby_thread;
    // uint8_t prof_op_id[OBOE_MAX_OP_ID_LEN];
    oboe_metadata_t* md = NULL;

    std::vector<std::string> prev_frames;
    std::vector<long> omitted;
} th_prof_data;

unordered_map<pid_t, th_prof_data> prof_data;

enum job_type{
    PROFILING_START,
    PROFILING_SNAPSHOT,
    PROFILING_STOP
};

typedef struct  {
    pid_t tid;
    job_type type;
    struct timeval timestamp;
    std::vector<std::string>frames;
} profiling_job;

// ReaderWriterQueue<profiling_job> queue(200);   


void 
process_snapshot(profiling_job job) {
    pid_t tid = job.tid;
    long ts = (long)job.timestamp.tv_sec * 1000000 + (long)job.timestamp.tv_usec;

    vector<FrameData> new_frame_data;
    vector<string> new_frames;
    int num_exited; 

    if (job.frames == prof_data[tid].prev_frames) {
        prof_data[tid].omitted.push_back(ts);
    } else {
        Frames::find_new_frames(job.frames,
                                prof_data[tid].prev_frames,
                                new_frames,
                                num_exited);
        Frames::extract_frame_info(new_frames, new_frame_data);
        Logging_V2::log_profile_snapshot(prof_data[tid].md,
                                         ts,
                                         new_frame_data,
                                         num_exited,
                                         job.frames.size(),
                                         prof_data[tid].omitted,
                                         tid);
    }

    prof_data[tid].prev_frames = job.frames;

}

void 
process_job(profiling_job job) {
    // cout << "processing ... " << job.tid << " " << job.type << endl;
    pid_t tid = job.tid;
    long ts = (long)job.timestamp.tv_sec * 1000000 + (long)job.timestamp.tv_usec;

    switch(job.type) {
        case PROFILING_START :
            Logging_V2::log_profile_entry(prof_data[tid].md,
                                          tid,
                                          ts,
                                          interval_v2);
            break;
        case PROFILING_SNAPSHOT :
            process_snapshot(job);
            break;
        case PROFILING_STOP :
            Logging_V2::log_profile_exit(prof_data[tid].md,
                                         tid,
                                         ts,
                                         prof_data[tid].omitted);
            prof_data[tid].omitted.clear();
            break;
    }
}

// void 
// profiling_thread() {
//     std::thread profiling_thread([]() {
//         profiling_job job;
//         while(1) {
//             if (queue.try_dequeue(job)) 
//                 process_job(job);
            
//                 // TODO remove entries for non-existing threads from prof_data
//             // else if (5 minutes have passed)
//                 // cleanup_prof_data(); 
//             else
//                 std::this_thread::sleep_for(std::chrono::milliseconds(100));
//         }
//     });
//     profiling_thread.detach();
// }

void 
take_snapshot(void *data) {
    struct timeval timestamp;
    gettimeofday(&timestamp, NULL); 
    // for each running thread in prof_data
    // for(pair<const pid_t, th_prof_data>& ele : prof_data) {
    //     if (ele.second.running_p) {
    //         profiling_job job = {ele.first, PROFILING_SNAPSHOT, timestamp, {}};

    //         VALUE backtrace = rb_funcall(ele.second.ruby_thread, rb_intern("backtrace"), 0);
    //         long n = RARRAY_LEN(backtrace);
    //         VALUE bt;
    //         for (long i = 0; i < n; i++) {
    //             bt = RARRAY_AREF(backtrace, i);
    //             // cout << RSTRING_PTR(bt) << endl;
    //             job.frames.push_back(RSTRING_PTR(bt));
    //             // job.frames.push_back("temp text");
    //         }
    //         // cout << "enqueuing snapshot for " << ele.first << endl;
    //         // queue.enqueue(job);
    //         auto handle = async(launch::async, process_job, job);
    //     }
    // }

    pid_t tid = AO_GETTID;

    VALUE backtrace = rb_funcall(prof_data[tid].ruby_thread, rb_intern("backtrace"), 0);
    long n = RARRAY_LEN(backtrace);
    VALUE bt;
    profiling_job job = {tid, PROFILING_SNAPSHOT, timestamp, {}};
    for (long i = 0; i < n; i++) {
        bt = RARRAY_AREF(backtrace, i);
        // cout << RSTRING_PTR(bt) << endl;
        job.frames.push_back(RSTRING_PTR(bt));
        // job.frames.push_back("temp text");
    }
    // cout << "enqueuing snapshot for " << ele.first << endl;
    // queue.enqueue(job);
    auto handle = async(launch::async, process_job, job);

}

void
snapshot_signal_handler(int sigint, siginfo_t *siginfo, void *ucontext) {
    // using postponed_job is important as the backtrace can't be taken during 
    // an signal interupt
    // cout << "in signal handler" << endl;
    rb_postponed_job_register_one(0, take_snapshot, (void *)0);
}


void
start_interval_timer() {
    if (running_count++ != 0) return;

    // cout << "start interval timer" << endl;

    // TODO figure out the mask and threads thing
    // it goes to the thread with the lowest number, maybe?

    // What happens if there is another action for the same signal?
    // => last one registered wins!

    struct sigaction sa;
    struct itimerval timer;

    sa.sa_sigaction = snapshot_signal_handler;
    sa.sa_flags = SA_RESTART | SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGALRM, &sa, NULL);

    timer.it_interval.tv_sec = 0;
    timer.it_interval.tv_usec = interval_v2 * 1000;
    timer.it_value = timer.it_interval;
    setitimer(ITIMER_REAL, &timer, 0);
}

void
stop_interval_timer() {
    if (running_count-- != 1) return;

    // cout << "stop interval timer" << endl;

    struct sigaction sa;
    struct itimerval timer;

    memset(&timer, 0, sizeof(timer));
    setitimer(ITIMER_REAL, &timer, 0);

    sa.sa_handler = SIG_IGN;
    sa.sa_flags = SA_RESTART;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGALRM, &sa, NULL);
}

int 
send_start_job(pid_t tid) {
    if (prof_data[tid].running_p) return 0;

    delete(prof_data[tid].md);
    prof_data[tid].md = Context::copy()->metadata();
    struct timeval timestamp;
    gettimeofday(&timestamp, NULL); 
    profiling_job job = {tid, PROFILING_START, timestamp, {}};
    // queue.enqueue(job);
    auto handle = async(launch::async, process_job, job);
    
    prof_data[tid].running_p = true;
    prof_data[tid].omitted.clear();
    // it seems that data expects ceil(time/interval) snapshots,
    // so I'm adding one at the beginning, 
    // not sure how well intervals need to be aligned, because the 
    // interval timer may already be ticking
    rb_postponed_job_register_one(0, take_snapshot, (void *)0);
    // cout << "enqueueing START " << job.tid << " counter " << running_count << endl;

    start_interval_timer();

    return 1;
}

void 
send_stop_job(pid_t tid) {
    prof_data[tid].running_p = false;

    stop_interval_timer();

    struct timeval timestamp;
    gettimeofday(&timestamp, NULL); 
    profiling_job job = {tid, PROFILING_STOP, timestamp, {}};
    // cout << "enqueueing STOP " << job.tid << " counter " << running_count << endl;
    // queue.enqueue(job);
    auto handle = async(launch::async, process_job, job);
}

VALUE 
Profiling_V2::profiling_run(VALUE self, VALUE rb_thread_val) {
    rb_need_block();  // checks if function is called with a block in Ruby

    pid_t tid = AO_GETTID;

    // VALUE backtrace = rb_funcall(rb_thread_val, rb_intern("inspect"), 0);
    // cout << "running for " << tid << " ruby thread info " << StringValueCStr(backtrace) << endl;
    prof_data[tid].ruby_thread = rb_thread_val;

    if (send_start_job(tid)) {
        rb_ensure(reinterpret_cast<VALUE (*)(...)>(rb_yield), Qundef,
                  reinterpret_cast<VALUE (*)(...)>(send_stop_job), tid);
    }
    // we never get here!!!
    return Qtrue;
}

VALUE 
Profiling_V2::set_interval(VALUE self, VALUE interval){
    if (!FIXNUM_P(interval)) return Qfalse;

    interval_v2 = FIX2INT(interval);

    return Qtrue;
}

VALUE 
Profiling_V2::getTid(){
    pid_t tid = AO_GETTID;

    return INT2NUM(tid);
}

static void
stackprof_atfork_prepare(void) {
    // cout << "Parent getting ready" << endl;
    struct itimerval timer;
    if (running_count) {
        memset(&timer, 0, sizeof(timer));
        setitimer(ITIMER_REAL, &timer, 0);
    }
}

static void
stackprof_atfork_parent(void) {
    // cout << "Parent let child loose" << endl;
    struct itimerval timer;
    if (running_count) {
        timer.it_interval.tv_sec = 0;
        timer.it_interval.tv_usec = interval_v2 * 1000;
        timer.it_value = timer.it_interval;
        setitimer(ITIMER_REAL, &timer, 0);
    }
}

static void
stackprof_atfork_child(void) {
    // cout << "A child is born" << endl;
}

extern "C" void Init_profiling_V2(void) {
    // cout << "Initializing Profiling" << endl;
    static VALUE rb_mAOProfiler_V2 = rb_define_module("AOProfiler_V2");
    rb_define_singleton_method(rb_mAOProfiler_V2, "set_interval", reinterpret_cast<VALUE (*)(...)>(Profiling_V2::set_interval), 1);
    rb_define_singleton_method(rb_mAOProfiler_V2, "run", reinterpret_cast<VALUE (*)(...)>(Profiling_V2::profiling_run), 1);
    rb_define_singleton_method(rb_mAOProfiler_V2, "getTid", reinterpret_cast<VALUE (*)(...)>(Profiling_V2::getTid), 0);

    // TODO start profiling thread
    // profiling_thread();

    // TODO better understand pthread_atfork
    // ____ doesn't seem to make a diff
    pthread_atfork(stackprof_atfork_prepare,
                   stackprof_atfork_parent,
                   stackprof_atfork_child);

}
