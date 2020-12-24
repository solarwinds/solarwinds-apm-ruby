// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "frames.h"

int Frames::cache_frame(VALUE frame) {
    VALUE val;
    FrameData data;

    if (cached_frames.count(frame) == 0) {
        val = rb_profile_frame_label(frame);  // returns method or block
        if (RB_TYPE_P(val, T_STRING))
            data.method = RSTRING_PTR(val);

        if (data.method.rfind("block ", 0) == 0) {
            // we don't need more info if it is a block
            // we ignore block level info because they make things messy
            // lock_guard<mutex> guard(cached_frames_mutex);
            cached_frames.insert({frame, data});
            return 0;
        }

        val = rb_profile_frame_classpath(frame);  // returns class or nil
        if (RB_TYPE_P(val, T_STRING)) data.klass = RSTRING_PTR(val);

        val = rb_profile_frame_absolute_path(frame);  // returns file, use rb_profile_frame_path() if nil
        if (!RB_TYPE_P(val, T_STRING)) val = rb_profile_frame_path(frame);
        if (RB_TYPE_P(val, T_STRING)) data.file = RSTRING_PTR(val);

        val = rb_profile_frame_first_lineno(frame);  // returns line number
        if (RB_TYPE_P(val, T_FIXNUM)) {
            data.lineno = NUM2INT(val);
        } else {
            data.lineno = -1;  // can be removed once the default set in oboe_api.cpp is -1
        }
        // lock_guard<mutex> guard(cached_frames_mutex);
        cached_frames.insert({frame, data});
    }
   return 0;
}

// all frames in frames_buffer must be in cached_frames before calling this function`
int Frames::collect_frame_data(VALUE *frames_buffer, int num, vector<FrameData> &frame_data) {
    if(frames_buffer[0] == PR_OTHER_THREAD) {
        FrameData data;
        data.method = "OTHER THREADS";
        frame_data.push_back(data);
        return 0;
    }

    for (int i = 0; i < num; i++) {
        VALUE frame = frames_buffer[i];
        frame_data.push_back(cached_frames[frame]);
    }

    return 0;
}

/////
// For the sake of efficiency this function filters uninteresting frames and
// does the caching of frames as well
//
// in-place removal of
// - frames with line number == 0
// - all but last of repeated frames
// - remove "block" frames (they are confusing)
// - caches the frames if not cached
int Frames::remove_garbage(VALUE *frames_buffer, int num) {
    if (frames_buffer[0] == PR_OTHER_THREAD)
        return 1;

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
                num--;
                // lock_guard<mutex> guard(cached_frames_mutex);
                cached_frames[frames_buffer[num - 1]].lineno = 0;
            }
        }
    }

    // 2) remove all repeated frames, keep the last one
    int count = 0;
    int k = 0;
    found = false;
    while (count < num-k) {
        // is this frame repeated ahead?
        // if so we will replace it with the next one in line
    	for(int j = count+k+1; j < num; j++) {
    	  if (frames_buffer[count] == frames_buffer[j]) {
    	  	found = true;
    	  	break;
    	  }
    	}

    	if (found){
            // if we found this frame again later in the snapshot
            // we are going to override this one
            // but not if this is going beyond the boundary
    		k++;
            if (count+k < num-1) frames_buffer[count] = frames_buffer[count+k];
        } else {
    		count++;
    		frames_buffer[count] = frames_buffer[count+k];
    	}
    	found = false;
    }

    // 3) remove "block" frames, they are reported inconsistently and mess up
    //    the profile in the dashboard
    // 4)  while we are at it we also cache all the frames
    num = count;
    count = 0, k = 0;
    string method;

    while (count < num - k) {
        frames_buffer[count] = frames_buffer[count + k];
        cache_frame(frames_buffer[count]);
        method = cached_frames[frames_buffer[count]].method;

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
        // start from the "top" (=end)
        if (frames_buffer[num - 1 - i] != prev_frames_buffer[prev_num - 1 - i]) {
            return i;
        }
    }

    return i;
 }

/////////////////////// DEBUGGING HELPER FUNCTIONS /////////////////////////////
// helper function to print frame from ruby pointers to frame
void Frames::print_raw_frame_info(VALUE frame) {
    if(frame == PR_OTHER_THREAD) {
        // cout << "OTHER_THREADS" << endl;
        return;
    }

    VALUE val;
    int lineno;
    string file, klass, method;

    val = rb_profile_frame_path(frame);

    val = rb_profile_frame_first_lineno(frame); // returns line number
    if (RB_TYPE_P(val, T_FIXNUM)) lineno = NUM2INT(val);

   val = rb_profile_frame_classpath(frame);  // returns class or nil
    if (RB_TYPE_P(val, T_STRING)) klass = RSTRING_PTR(val);

    val = rb_profile_frame_absolute_path(frame);  // returns file, use rb_profile_frame_path() if nil
    if (!RB_TYPE_P(val, T_STRING)) val = rb_profile_frame_path(frame);
    if (RB_TYPE_P(val, T_STRING)) file = RSTRING_PTR(val);

    val = rb_profile_frame_label(frame);  // returns method or block
    if (RB_TYPE_P(val, T_STRING)) method = RSTRING_PTR(val);

    cout << "   "
         << lineno << " "
         << file << " "
         << klass << " "
         << method << endl;
}

// helper function to print frame info
void Frames::print_frame_info(FrameData &frame, int i) {
    std::cout << i << ": "
              << frame.lineno << " "
              << frame.file << " "
              << frame.klass << " "
              << frame.method << std::endl;
}

