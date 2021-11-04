// Copyright (c) 2021 SolarWinds, LLC.
// All rights reserved.

#include "frames.h"

using namespace std;

unordered_map<VALUE, FrameData> cached_frames;

// in theory the mutex is not needed, because Ruby does not context switch
// while executing a foreign function, but will this always hold true?
mutex cached_frames_mutex;

void Frames::reserve_cached_frames() {
    lock_guard<mutex> guard(cached_frames_mutex);
    // unordered_maps grow automatically, but it starts at 1 and then
    // doubles when it is full, so lets avoid the warmup
    cached_frames.reserve(500);  // it will round to a prime number: 503
}

void Frames::clear_cached_frames() {
    lock_guard<mutex> guard(cached_frames_mutex);
        // unordered_maps grow automatically, but it starts at 1 and then
        // doubles when it is full, so lets avoid the warmup
    cached_frames.clear();
}

// this is a private function
int Frames::cache_frame(VALUE frame) {
    VALUE val;
    FrameData data;

    // only cache it if it does not exist
    if (cached_frames.count(frame) == 0) {
        val = rb_profile_frame_label(frame);  // returns method or block
        if (RB_TYPE_P(val, T_STRING))
            data.method = RSTRING_PTR(val);

        if (data.method.rfind("block ", 0) == 0) {
            // we don't need more info if it is a block
            // we ignore block level info because they make things messy
            lock_guard<mutex> guard(cached_frames_mutex);
            cached_frames.insert({frame, data});
            return 0;
        }

        val = rb_profile_frame_classpath(frame);  // returns class or nil
        if (RB_TYPE_P(val, T_STRING)) data.klass = RSTRING_PTR(val);

        val = rb_profile_frame_absolute_path(frame);  // returns file, use rb_profile_frame_path() if nil
        if (!RB_TYPE_P(val, T_STRING)) val = rb_profile_frame_path(frame);
        if (RB_TYPE_P(val, T_STRING)) data.file = RSTRING_PTR(val);

        // Ruby 3 reports <cfunc>, but the linenumbers are bogus
        // the default line number is 0
        if (!data.file.compare("<cfunc>") == 0) {
            val = rb_profile_frame_first_lineno(frame);  // returns line number
            if (RB_TYPE_P(val, T_FIXNUM)) {
                data.lineno = NUM2INT(val);
            }
        }
        lock_guard<mutex> guard(cached_frames_mutex);
        cached_frames.insert({frame, data});
    }
    return 0;
}

// all frames in frames_buffer must be in cached_frames
// before calling this function
// we are saving the check for better performance
int Frames::collect_frame_data(VALUE *frames_buffer, int num, vector<FrameData> &frame_data) {
    if (num == 1) {
        if (frames_buffer[0] == PR_IN_GC) {
            FrameData data;
            data.method = "GARBAGE COLLECTION";
            frame_data.push_back(data);
            return 0;
        } else if (frames_buffer[0] == PR_OTHER_THREAD) {
            FrameData data;
            data.method = "OTHER THREADS";
            frame_data.push_back(data);
            return 0;
        }
    }

    for (int i = 0; i < num; i++) {
        VALUE frame = frames_buffer[i];
        frame_data.push_back(cached_frames[frame]);
    }
    return 0;
}

/////
// For the sake of efficiency this function filters uninteresting frames and
// does the caching of frames at the same time
//
// in-place removal of
// - frames with line number == 0
// - all but last of repeated frames
// - "block" frames (they are confusing) <- revisit
// and cache uncached frames
int Frames::remove_garbage(VALUE *frames_buffer, int num) {
    if (num == 1 && (frames_buffer[0] == PR_OTHER_THREAD || frames_buffer[0] == PR_IN_GC))
        return 1;

    // TODO decide what to do with <cfunc> frames in Ruby 3
    // ____ AO-20269

    // 1) ignore top frames where the line number is 0
    // does that mean there is no line number???
    bool found = true;

    while (found && num > 0) {
        if (cached_frames.count(frames_buffer[num - 1]) == 1) {
            found = (cached_frames[frames_buffer[num - 1]].lineno == 0);
            if (found) num--;
        } else {
            VALUE val = rb_profile_frame_first_lineno(frames_buffer[num - 1]);
            found = (!RB_TYPE_P(val, T_FIXNUM) || !NUM2INT(val));
            if (found) {
                lock_guard<mutex> guard(cached_frames_mutex);
                cached_frames[frames_buffer[num - 1]].lineno = 0;
                num--;
            }
        }
    }

    // 2) remove all repeated frames, keep the last one
    int count = 0;
    int k = 0;
    found = false;
    while (count < num - k) {
        // is this frame repeated ahead?
        // if so we will replace it with the next one in line
        for (int j = count + k + 1; j < num; j++) {
            if (frames_buffer[count] == frames_buffer[j]) {
                found = true;
                break;
            }
        }

        if (found) {
            // if we found this frame again later in the snapshot
            // we are going to override this one
            // but not if this is going beyond the boundary
            k++;
            if (count + k < num - 1) frames_buffer[count] = frames_buffer[count + k];
        } else {
            count++;
            frames_buffer[count] = frames_buffer[count + k];
        }
        found = false;
    }

    // 3) remove "block" frames, they are reported inconsistently and mess up
    //    the profile in the dashboard
    // 4)  while we are at it we also cache all the frames
    // these 2 are combined so we don't have to run this loop twice
    num = count;
    count = 0, k = 0;
    string method;

    while (count < num - k) {
        frames_buffer[count] = frames_buffer[count + k];
        cache_frame(frames_buffer[count]);
        method = cached_frames[frames_buffer[count]].method;

        // TODO revisit need to remove block frames, they only appear when the Ruby
        // ____ script is not started with a method and has blocks outside of the
        // ____ methods called and sometimes inside of rack
        if (method.rfind("block ", 0) == 0) {
            k++;
        } else {
            count++;
        }
    }
    return count;
}

// returns the number of the matching frames
int Frames::num_matching(VALUE *frames_buffer, int num,
                         VALUE *prev_frames_buffer, int prev_num) {
    int i;
    int min = std::min(num, prev_num);

    for (i = 0; i < min; i++) {
        // we have to start from the "top"
        if (frames_buffer[num - 1 - i] != prev_frames_buffer[prev_num - 1 - i]) {
            return i;
        }
    }
    return i;
}

/////////////////////// DEBUGGING HELPER FUNCTIONS /////////////////////////////
// helper function to print frame from ruby pointers to frame
void Frames::print_raw_frame_info(VALUE frame) {
    if (frame == PR_IN_GC || frame == PR_OTHER_THREAD) {
        return;
    }

    VALUE val;
    int lineno;
    string file, klass, method;

    val = rb_profile_frame_first_lineno(frame);  // returns line number
    if (RB_TYPE_P(val, T_FIXNUM)) lineno = NUM2INT(val);

    val = rb_profile_frame_classpath(frame);  // returns class or nil
    if (RB_TYPE_P(val, T_STRING)) klass = RSTRING_PTR(val);

    val = rb_profile_frame_absolute_path(frame);  // returns file, use rb_profile_frame_path() if nil
    if (!RB_TYPE_P(val, T_STRING)) val = rb_profile_frame_path(frame);
    if (RB_TYPE_P(val, T_STRING)) file = RSTRING_PTR(val);

    val = rb_profile_frame_label(frame);  // returns method or block
    if (RB_TYPE_P(val, T_STRING)) method = RSTRING_PTR(val);

    cout << "    " << frame << "   "
         << "L: " << lineno << " "
         << "F: " << file << " "
         << "C: " << klass << " "
         << "M: " << method << endl;
}

void Frames::print_all_raw_frames(VALUE *frames_buffer, int num) {
    for (int i = 0; i < num; i++) {
        print_raw_frame_info(frames_buffer[i]);
    }
}

// helper function to print frame info
void Frames::print_frame_info(VALUE frame) {
    if (cached_frames.find(frame) != cached_frames.end())
        std::cout << cached_frames[frame].lineno << " "
                  << cached_frames[frame].file << " "
                  << cached_frames[frame].klass << " "
                  << cached_frames[frame].method << std::endl;
}

// helper function for printing the cached frames
void Frames::print_cached_frames() {
    std::cout << "cached_frames contains:" << endl;
    for (auto it = cached_frames.cbegin(); it != cached_frames.cend(); ++it)
        std::cout << "           " << it->first << " - " << it->second.method << ":" << it->second.lineno << endl;  // cannot modify *it
    std::cout << std::endl;
}
