// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "logging.h"

uint8_t prof_op_id[OBOE_MAX_OP_ID_LEN];

const char hexmap[] = {'0', '1', '2', '3', '4', '5', '6', '7',
                       '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

std::string hexStr2(unsigned char *data, int len) {
    std::string s(len * 2, ' ');
    for (int i = 0; i < len; ++i) {
        s[2 * i] = hexmap[(data[i] & 0xF0) >> 4];
        s[2 * i + 1] = hexmap[data[i] & 0x0F];
    }
    return s;
}

oboe_metadata_t *md;

std::ostringstream ss;

Event *Logging::startEvent(bool entry_event = false) {
    
    Event *event = Event::startTrace(md); // startTrace does not add "Edge"
    if (entry_event) {
        event->addSpanRef(md);
    } else {
        event->addProfileEdge(prof_op_id);
        std::cout << hexStr2(prof_op_id, OBOE_MAX_OP_ID_LEN) << " - ";
    }
    event->storeOpID(prof_op_id);
    std::cout << hexStr2(prof_op_id, OBOE_MAX_OP_ID_LEN) << std::endl;
    return event;
}

bool Logging::log_profile_entry(long interval) {
    std::cout << "profile entry, " << Context::toString() << std::endl;
    md = Context::get();
    // oboe_metadata_t *md = Context::get();
    // Event *event = Logging::startEvent();
     
    Event *event = Logging::startEvent(true);
    event->addInfo((char *)"Label", "entry");
    event->addInfo((char *)"Language", "ruby");
    event->addInfo((char *)"Interval", interval/1000);

    struct timeval tv;
    oboe_gettimeofday(&tv);
    event->addInfo((char *)"Timestamp_u", (long)((long)tv.tv_sec * 1000000 + (long)tv.tv_usec));

    return Logging::log_profile_event(event);
}

bool Logging::log_profile_exit(std::vector<long> const &ommitted) {
    std::cout << "profile exit, " << Context::toString() << std::endl;

    Event *event = Logging::startEvent();
    event->addInfo((char *)"Label", "exit");
    event->addInfo((char *)"SnapshotsOmitted", ommitted);

    struct timeval tv;
    oboe_gettimeofday(&tv);
    event->addInfo((char *)"Timestamp_u", (long)tv.tv_sec * 1000000 + (long)tv.tv_usec);

    return Logging::log_profile_event(event);
};

bool Logging::log_profile_snapshot(long timestamp,
                                   std::vector<frame_t> const &new_frames,
                                   int num_new_frames,
                                   long exited_frames,
                                   long total_frames,
                                   std::vector<long> const &ommitted) {
 
    struct timeval tv;
    oboe_gettimeofday(&tv);

    Event *event = Logging::startEvent();
    event->addInfo((char *)"Timestamp_u", (long)tv.tv_sec * 1000000 + (long)tv.tv_usec);
    event->addInfo((char *)"Label", "info");
    
    event->addInfo((char *)"SnapshotsOmitted", ommitted);
    event->addInfo((char *)"NewFrames", new_frames, num_new_frames);
    event->addInfo((char *)"FramesExited", exited_frames);
    event->addInfo((char *)"FramesCount", total_frames);

    return Logging::log_profile_event(event);
}

bool Logging::log_profile_event(Event *event) {
    event->addInfo((char *)"Spec", "profiling");
    event->addHostname();
    event->addInfo((char *)"PID", (long)AO_GETPID());
    event->addInfo((char *)"X-Trace", event->metadataString());

    event->send_profiling();
    event->storeOpID(prof_op_id);            // keep track of the edge

    return true;
}
