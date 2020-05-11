// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "logging.h"

// uint8_t context_op_id[OBOE_MAX_OP_ID_LEN];

const char hexmap[] = {'0', '1', '2', '3', '4', '5', '6', '7',
                       '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

string hex2Str(unsigned char *data, int len) {
    string s(len * 2, ' ');
    for (int i = 0; i < len; ++i) {
        s[2 * i] = hexmap[(data[i] & 0xF0) >> 4];
        s[2 * i + 1] = hexmap[data[i] & 0x0F];
    }
    return s;
}

std::ostringstream ss;

Event *Logging::createEvent(uint8_t *prof_op_id, bool entry_event) {
    oboe_metadata_t* md = Context::get();

    Event *event = Event::startTrace(md); // startTrace does not add "Edge"
    if (entry_event) {
        event->addSpanRef(md);
    } else {
        event->addProfileEdge(prof_op_id);
    }
    event->storeOpID(prof_op_id);
    event->addOpId((char *)"ContextOpId", md);
    return event;
}

bool Logging::log_profile_entry(uint8_t *prof_op_id, pid_t tid, long interval) {

    // PROFILE_FUNCTION();
    Event *event = Logging::createEvent(prof_op_id, true);
    event->addInfo((char *)"Label", "entry");
    event->addInfo((char *)"Language", "ruby");
    event->addInfo((char *)"TID", (long)tid);
    event->addInfo((char *)"Interval", interval);

    struct timeval tv;
    oboe_gettimeofday(&tv);
    event->addInfo((char *)"Timestamp_u", (long)((long)tv.tv_sec * 1000000 + (long)tv.tv_usec));

    return Logging::log_profile_event(event);
}

bool Logging::log_profile_exit(uint8_t *prof_op_id, pid_t tid, long *omitted, int num_omitted) {

    // PROFILE_FUNCTION();
    Event *event = Logging::createEvent(prof_op_id);
    event->addInfo((char *)"Label", "exit");
    event->addInfo((char *)"TID", (long)tid);
    event->addInfo((char *)"SnapshotsOmitted", omitted, num_omitted);

    struct timeval tv;
    oboe_gettimeofday(&tv);
    event->addInfo((char *)"Timestamp_u", (long)tv.tv_sec * 1000000 + (long)tv.tv_usec);

    return Logging::log_profile_event(event);
};

bool Logging::log_profile_snapshot(uint8_t *prof_op_id, 
                                   long timestamp,
                                   std::vector<frame_t> const &new_frames,
                                   int num_new_frames,
                                   long exited_frames,
                                   long total_frames,
                                   long *omitted,
                                   int num_omitted,
                                   pid_t tid) {
 
    // PROFILE_FUNCTION();
    Event *event = Logging::createEvent(prof_op_id);
    event->addInfo((char *)"Timestamp_u", timestamp);
    event->addInfo((char *)"Label", "info");
    
    event->addInfo((char *)"SnapshotsOmitted", omitted, num_omitted);
    event->addInfo((char *)"NewFrames", new_frames, num_new_frames);
    event->addInfo((char *)"FramesExited", exited_frames);
    event->addInfo((char *)"FramesCount", total_frames);
    event->addInfo((char *)"TID", (long)tid);


    return Logging::log_profile_event(event);
}

bool Logging::log_profile_event(Event *event) {
    // PROFILE_FUNCTION();
    event->addInfo((char *)"Spec", "profiling");
    event->addHostname();
    event->addInfo((char *)"PID", (long)AO_GETPID());
    event->addInfo((char *)"X-Trace", event->metadataString());
    event->send_profiling();

    delete event;
    return true;
}
