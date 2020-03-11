// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef LOGGING_H
#define LOGGING_H

#include <iostream>
#include <sstream> 
#include <vector>

#include "oboe.hpp"
#include "profiling.h"

extern "C" int oboe_gettimeofday(struct timeval *tv);

class Logging {
   public:
    static Event *startEvent(bool entry_event);
    static bool log_profile_entry(long interval);
    static bool log_profile_exit(std::vector<long> const &ommitted);
    static bool log_profile_snapshot(long timestamp,
                                     std::vector<frame_t> const &new_frames,
                                     int num_new_frames,
                                     long exited_frames,
                                     long total_frames,
                                     std::vector<long> const &ommitted);
    static bool log_profile_event(Event *event);
};


#endif  //LOGGING_H
