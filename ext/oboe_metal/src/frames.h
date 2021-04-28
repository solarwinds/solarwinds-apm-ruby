// Copyright (c) 2021 SolarWinds, LLC.
// All rights reserved.

#ifndef FRAMES_H
#define FRAMES_H

#include <vector>

#include <mutex>
#include <unordered_map>

#include <ruby/ruby.h>
#include <ruby/debug.h>

#include "profiling.h"
#include "oboe_api.hpp"

using namespace std;

class Frames {
   public:
    static void clear_cached_frames();
    static void reserve_cached_frames();
    static int collect_frame_data(VALUE *frames_buffer, int num, vector<FrameData> &frame_data);
    static int remove_garbage(VALUE *frames_buffer, int num);
    static int num_matching(VALUE *frames_buffer, int num,
                            VALUE *prev_frames_buffer, int prev_num);

   private:
    static int cache_frame(VALUE frame);

    // Debugging helper functions
   public:
    static void print_raw_frame_info(VALUE frame);
    static void print_all_raw_frames(VALUE *frames_buffer, int num);
    static void print_frame_info(VALUE frame);
    static void print_cached_frames();
};

#endif //FRAMES_H
