// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "frames.h"

int Frames::extract_frame_info(VALUE *frames_buffer, int num, vector<FrameData> &frame_data) {
    VALUE val;

    if(frames_buffer[0] == PR_OTHER_THREAD) {
        FrameData data;
        data.method = "OTHER THREADS";
        frame_data.push_back(data);
        return 0;
    }

    for(int i = 0; i < num; i++) {
        VALUE frame = frames_buffer[i];
        FrameData data;

        if (cached_frames.count(frame) == 1 && getenv("AO_CACHE_FRAMES")) {
            frame_data.push_back(cached_frames[frame]);
            continue;
        }

        // if (cached_frames.count(frame) == 0) {
            val = rb_profile_frame_label(frame);  // returns method or block
            if (RB_TYPE_P(val, T_STRING)) data.method = RSTRING_PTR(val);

            // we ignore block level info because they make things messy
            if (data.method.rfind("block ", 0) == 0)
                continue;

            val = rb_profile_frame_classpath(frame);  // returns class or nil
            if (RB_TYPE_P(val, T_STRING)) data.klass = RSTRING_PTR(val);

            val = rb_profile_frame_absolute_path(frame);  // returns file, use rb_profile_frame_path() if nil
            if (!RB_TYPE_P(val, T_STRING)) val = rb_profile_frame_path(frame);
            if (RB_TYPE_P(val, T_STRING)) data.file = RSTRING_PTR(val);

            val = rb_profile_frame_first_lineno(frame);  // returns line number
            if (RB_TYPE_P(val, T_FIXNUM)) data.lineno = NUM2INT(val);

            if (getenv("AO_CACHE_FRAMES"))
                cached_frames[frame] = data;
            // }

            frame_data.push_back(data);
    }
 
    return 0;
}

/////
// in-place removal of 
// - frames with line number == 0
// - all but last of repeated frames
// - remove "block" frames (they are confusing)
int Frames::remove_garbage(VALUE *frames_buffer, int num) {
    if (frames_buffer[0] == PR_OTHER_THREAD)
        return 1;

    // 1) ignore top frames where the line number is 0
    bool found = true;
    while(found && num > 0) {
        VALUE val = rb_profile_frame_first_lineno(frames_buffer[num - 1]);
        found = (!RB_TYPE_P(val, T_FIXNUM) || !NUM2INT(val));
        if (found) num--;
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

    	if(found){
            // if we found this frame again later in the snapshot
            // we are going to override this one
            // but not if this is going beyond the boundary
    		k++;
            if(count+k < num-1) frames_buffer[count] = frames_buffer[count+k];
        } else {
    		count++;
    		frames_buffer[count] = frames_buffer[count+k];
    	}
    	found = false;
    }

    // 3) remove "block" frames, they are reported inconsistently and mess up
    //    the profile in the dashboard
    num = count;
    count = 0, k = 0;
    VALUE val;
    string method, file;
    while(count < num-k) {
       frames_buffer[count] = frames_buffer[count+k];
       val = rb_profile_frame_label(frames_buffer[count]);  // returns method or block
       // get the method or use block if its not readable
       method = RB_TYPE_P(val, T_STRING) ? RSTRING_PTR(val) : "block ";

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

