// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef FRAMES_H
#define FRAMES_H

#include "profiling.h"

class Frames {
    public:
    static int extract_frame_info(VALUE frame, FrameData *frame_info);
    static int remove_garbage(VALUE *frames_buffer, int num);
    static int num_matching(VALUE *frames_buffer, int num,
                       VALUE *prev_frames_buffer, int prev_num);
    static void print_raw_frame_info(VALUE frame);
    static void print_frame_info(FrameData *frame_info, int i);
};

#endif //FRAMES_H
