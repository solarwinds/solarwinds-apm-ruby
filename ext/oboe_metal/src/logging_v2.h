// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef LOGGING_V2_H
#define LOGGING_V2_H

// #include <iostream>
// #include <sstream>

#include "oboe.hpp"

extern "C" int oboe_gettimeofday(struct timeval *tv);

class Logging_V2 {
   public:
    static Event *createEvent(oboe_metadata_t* md, bool entry_event = false);
    static bool log_profile_entry(oboe_metadata_t *md,
                                  pid_t tid,
                                  long timestamp,
                                  long interval);
    static bool log_profile_exit(oboe_metadata_t *md,
                                 pid_t tid,
                                 long timestamp,
                                 std::vector<long> omitted);
    static bool log_profile_snapshot(oboe_metadata_t* md,
                                     long timestamp,
                                     const std::vector<FrameData> &new_frames,
                                     long exited_frames,
                                     long total_frames,
                                     const std::vector<long> &omitted,
                                     pid_t tid);
    static bool log_profile_event(Event *event);
};

#endif  //LOGGING_V2_H
