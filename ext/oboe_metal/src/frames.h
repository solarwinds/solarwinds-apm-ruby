#ifndef FRAMES_H
#define FRAMES_H

#include <iostream>
#include <algorithm>
#include <bits/stdc++.h> 

#include <ruby/ruby.h>
#include <ruby/intern.h>
#include <ruby/debug.h>

#include "profiling.h"
#include "ruby_headers/collection.h"

class Frames {
    public:
    static int extract_frame_info(VALUE frame, frame_t *frame_info);
    static void print_raw_frame_info(VALUE frame);
    static void print_frame_info(frame_t *frame_info, int i);
};


class Snapshot {
    public:
    static int remove_garbage(VALUE *frames_buffer, int num, string app_root);
    static int compare(VALUE *frames_buffer, int num,
                       VALUE *prev_frames_buffer, int prev_num);
};

#endif //FRAMES_H
