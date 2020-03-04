// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#ifndef LOGGING_H
#define LOGGING_H

#include <iostream>
#include <string>
#include <sstream> 
#include <vector>

#include "oboe.hpp"

//TODO move to oboe.h
extern "C" int oboe_gettimeofday(struct timeval *tv);

class Frame {
   public:
    Frame(std::string klass, std::string method, std::string filename, int lineno);

    std::string toString();
};

class Logging {
   public:
    static bool log_profile_entry();
    static bool log_profile_exit(std::vector<long> const &ommitted);
    static bool log_profile_snapshot(long timestamp,
                                     std::vector<Frame> new_frames,
                                     int exited_frames,
                                     int total_frames,
                                     std::vector<long> ommitted);
    static bool log_profile_event(Event *event);
};


#endif  //LOGGING_H
