// Copyright (c) 2021 SolarWinds, LLC.
// All rights reserved.

#ifndef FRAMES_H
#define FRAMES_H

#include <vector>

#include <ruby/ruby.h>

#include "oboe_api.hpp"

using namespace std;

class Frames {
    public:
    static void reserve_cached_frames();
    static int cache_frame(VALUE);
    static int collect_frame_data(VALUE *frames_buffer, int num, vector<FrameData>&frame_data);
    static int remove_garbage(VALUE *frames_buffer, int num);
    static int num_matching(VALUE *frames_buffer, int num,
                       VALUE *prev_frames_buffer, int prev_num);
    // Debugging helper functions
    static void print_raw_frame_info(VALUE frame);
    static void print_frame_info(VALUE frame);
    static void print_cached_frames();

};

#endif //FRAMES_H
