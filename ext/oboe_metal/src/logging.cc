// Copyright (c) 2021 SolarWinds, LLC.
// All rights reserved.

#include "logging.h"

const string Logging::profiling = "profiling";
const string Logging::ruby = "ruby";
const string Logging::entry = "entry";
const string Logging::info = "info";
const string Logging::exit = "exit";

Event *Logging::createEvent(oboe_metadata_t* md, string &prof_op_id, bool entry_event) {
    // startTrace does not add "Edge", we need to keep track of edges separately
    // from the trace metadata for profiling
    Event *event = Event::startTrace(md);

    if (entry_event) {
        event->addSpanRef(md);
    } else {
        event->addProfileEdge(prof_op_id);
        event->addContextOpId(md);
    }
    prof_op_id.assign(event->opIdString());

    return event;
}

bool Logging::log_profile_entry(oboe_metadata_t* md, string &prof_op_id, pid_t tid, long interval) {
    Event *event = Logging::createEvent(md, prof_op_id, true);
    event->addInfo((char *)"Label", Logging::entry);
    event->addInfo((char *)"Language", Logging::ruby);
    event->addInfo((char *)"TID", (long)tid);
    event->addInfo((char *)"Interval", interval);

    struct timeval tv;
    oboe_gettimeofday(&tv);
    event->addInfo((char *)"Timestamp_u", (long)tv.tv_sec * 1000000 + (long)tv.tv_usec);

    return Logging::log_profile_event(event);
}

bool Logging::log_profile_exit(oboe_metadata_t *md, string &prof_op_id, pid_t tid,
                               long *omitted, int num_omitted) {
    Event *event = Logging::createEvent(md, prof_op_id);
    event->addInfo((char *)"Label", Logging::exit);
    event->addInfo((char *)"TID", (long)tid);
    event->addInfo((char *)"SnapshotsOmitted", omitted, num_omitted);

    struct timeval tv;
    oboe_gettimeofday(&tv);
    event->addInfo((char *)"Timestamp_u", (long)tv.tv_sec * 1000000 + (long)tv.tv_usec);

    return Logging::log_profile_event(event);
}

bool Logging::log_profile_snapshot(oboe_metadata_t* md,
                                   string &prof_op_id,
                                   long timestamp,
                                   std::vector<FrameData> const &new_frames,
                                   long exited_frames,
                                   long total_frames,
                                   long *omitted,
                                   int num_omitted,
                                   pid_t tid) {

    Event *event = Logging::createEvent(md, prof_op_id);
    event->addInfo((char *)"Timestamp_u", timestamp);
    event->addInfo((char *)"Label", Logging::info);

    event->addInfo((char *)"SnapshotsOmitted", omitted, num_omitted);
    event->addInfo((char *)"NewFrames", new_frames);
    event->addInfo((char *)"FramesExited", exited_frames);
    event->addInfo((char *)"FramesCount", total_frames);
    event->addInfo((char *)"TID", (long)tid);


    return Logging::log_profile_event(event);
}

bool Logging::log_profile_event(Event *event) {
        event->addInfo((char *)"Spec", Logging::profiling);
        event->addHostname();
        event->addInfo((char *)"PID", (long)AO_GETPID());
        event->addInfo((char *)"X-Trace", event->metadataString());
        event->sendProfiling();

        // see comment in oboe_api.cpp:
        // "event needs to be deleted, it is managed by swig %newobject"
        // !!! It needs to be deleted, I tested it !!!
        delete event;
        return true;
}
