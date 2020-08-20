// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef FRAMES_V2_H
#define FRAMES_V2_H

#include "profiling_v2.h"


class Frames {
    public:
    static int find_new_frames(const vector<string> frames,
                               const vector<string> prev_frames,
                               vector<string> &new_frames,
                               int &num_exited);
    static int extract_frame_info(const vector<string> frames, vector<FrameData> &frame_data);
};

#endif // FRAMES_V2_H