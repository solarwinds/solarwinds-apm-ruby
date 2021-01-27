// Copyright (c) 2021 SolarWinds, LLC.
// All rights reserved.

#ifndef LOGGING_H
#define LOGGING_H

#include "oboe_api.hpp"

using namespace std;

extern "C" int oboe_gettimeofday(struct timeval *tv);

class Logging {
   public:
    static bool log_profile_entry(oboe_metadata_t* md, string &prof_op_id, pid_t tid, long interval);
    static bool log_profile_exit(oboe_metadata_t *md, string &prof_op_id, pid_t tid,
                                 long *omitted, int num_omitted);
    static bool log_profile_snapshot(oboe_metadata_t *md,
                                     string &prof_op_id,
                                     long timestamp,
                                     std::vector<FrameData> const &new_frames,
                                     long exited_frames,
                                     long total_frames,
                                     long *omitted,
                                     int num_omitted,
                                     pid_t tid);

   private:
    static Event *createEvent(oboe_metadata_t *md, string &prof_op_id, bool entry_event = false);
    static bool log_profile_event(Event *event);
};

#endif  //LOGGING_H
