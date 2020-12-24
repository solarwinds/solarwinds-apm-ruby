// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef FRAMES_H
#define FRAMES_H

#include "profiling.h"

extern thread_local unordered_map<VALUE, FrameData> th_cached_frames;

extern unordered_map<VALUE, FrameData> cached_frames;
extern mutex cached_frames_mutex;

class Frames {
    public:
    static int cache_frame(VALUE);
    static int collect_frame_data(VALUE *frames_buffer, int num, vector<FrameData>&frame_data);
    static int remove_garbage(VALUE *frames_buffer, int num);
    static int num_matching(VALUE *frames_buffer, int num,
                       VALUE *prev_frames_buffer, int prev_num);
    static void print_raw_frame_info(VALUE frame);
    static void print_frame_info(FrameData &frame_data, int i);
};

#endif //FRAMES_H
