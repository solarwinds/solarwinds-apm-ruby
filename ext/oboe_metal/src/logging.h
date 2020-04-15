// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef LOGGING_H
#define LOGGING_H

#include <iostream>
#include <sstream> 
#include <vector>
#include <sys/syscall.h>    /* For SYS_xxx definitions */

#include "profiling.h"
#include "frames.h"

extern "C" int oboe_gettimeofday(struct timeval *tv);

class Logging {
   public:
    static Event *createEvent(bool entry_event);
    static bool log_profile_entry(long interval);
    static bool log_profile_exit(long *omitted, int num_omitted);
    static bool log_profile_snapshot(long timestamp,
                                     std::vector<frame_t> const &new_frames,
                                     int num_new_frames,
                                     long exited_frames,
                                     long total_frames,
                                     long *omitted,
                                     int num_omitted,
                                     long tid);
    static bool log_profile_event(Event *event);
};

#endif  //LOGGING_H
