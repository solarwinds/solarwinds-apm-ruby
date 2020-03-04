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

std::ostringstream ss;

bool Logging::log_profile_entry() {
    std::cout << "profile entry, " << Context::toString() << std::endl;

    oboe_metadata_t *md = Context::get();
    Event *event = Event::startTrace(md);  // startTrace does not add "Edge"
    event->getOpID(prof_op_id);            // keep track of the edge

    event->addSpanRef(md);  // ref to edge of current trace context
    event->addInfo((char *)"Label", "entry");
    event->addInfo((char *)"Language", "ruby");
    event->addInfo((char *)"Interval", (long)oboe_get_profiling_interval());

    struct timeval tv;
    oboe_gettimeofday(&tv);
    event->addInfo((char *)"Timestamp_u", (long)((long)tv.tv_sec * 1000000 + (long)tv.tv_usec));

    return Logging::log_profile_event(event);
    ;
}

bool Logging::log_profile_exit(std::vector<long> const &ommitted) {
    std::cout << "profile exit, " << Context::toString() << std::endl;

    oboe_metadata_t *md = Context::get();
    Event *event = Event::startTrace(md);  // startTrace does not add "Edge"
    event->addContextOpId(prof_op_id);

    event->addInfo((char *)"Label", "exit");

    ss.seekp(std::ios::beg);
    ss << '[';
    for (unsigned int i = 0; i < ommitted.size(); i++) {
        ss << ommitted.at(i);
        if (i < ommitted.size() - 1)
            ss << ',';
        else
            ss << ']' << '\0';
    }

    event->addInfo((char *)"SnapshotsOmitted", ss.str().c_str());

    struct timeval tv;
    oboe_gettimeofday(&tv);
    event->addInfo((char *)"Timestamp_u", (long)tv.tv_sec * 1000000 + (long)tv.tv_usec);

    return Logging::log_profile_event(event);
};

// TODO can't use the automatic timestamp from oboe
bool Logging::log_profile_snapshot(long timestamp,
                                   std::vector<Frame> new_frames,
                                   int exited_frames,
                                   int total_frames,
                                   std::vector<long> ommitted) {
    // event->addInfo((char *)"PID", (long)AO_GETPID());

    return true;
}

bool Logging::log_profile_event(Event *event) {
    event->addInfo((char *)"Spec", "profiling");
    event->addHostname();
    event->addInfo((char *)"PID", (long)AO_GETPID());
    event->addInfo((char *)"X-Trace", event->metadataString());

    event->send_profiling();

    return true;
}
