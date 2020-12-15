// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef FRAMES_H
#define FRAMES_H

#include "profiling.h"

extern thread_local unordered_map<VALUE, FrameData> cached_frames;

class Frames {
    public:
    static int extract_frame_info(VALUE *frames_buffer, int num, vector<FrameData>&frame_data);
    static int remove_garbage(VALUE *frames_buffer, int num);
    static int num_matching(VALUE *frames_buffer, int num,
                       VALUE *prev_frames_buffer, int prev_num);
    static void print_raw_frame_info(VALUE frame);
    static void print_frame_info(FrameData &frame_data, int i);
};

#endif //FRAMES_H
