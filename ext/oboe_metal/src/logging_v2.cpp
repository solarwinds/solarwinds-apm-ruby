// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "logging_v2.h"
using namespace std;

Event *Logging_V2::createEvent(oboe_metadata_t* md, bool entry_event) {
    Event *event = Event::startTrace(md); // startTrace does not add "Edge"
    if (entry_event) {
        event->addSpanRef(md);
    } else {
        event->addProfileEdge(md);
    }
    // TODO this would have to be passed in
    // event->addOpId((char *)"ContextOpId", (oboe_metadata_t *)md);
    // cout << "md op_id " << (oboe_metadata_t *)md->ids.op_id
    //      << ", event op_id " << (oboe_metadata_t *)(event->getMetadata())->ids.op_id  
    //      << endl;
    // md = ((oboe_event_t *)event)->metadata.ids.op_id;
    // ((oboe_event_t *)event)->metadata.ids.op_id;

    event->storeOpID(md->ids.op_id);
    return event;
}

bool Logging_V2::log_profile_entry(oboe_metadata_t* md, pid_t tid, long timestamp, long interval) {
    Event *event = Logging_V2::createEvent(md, true);
    event->addInfo((char *)"Label", "entry");
    event->addInfo((char *)"Language", "ruby");
    event->addInfo((char *)"TID", (long)tid);
    event->addInfo((char *)"Timestamp_u", timestamp);
    event->addInfo((char *)"Interval", interval);
    event->addInfo((char *)"Profiling_V2", (long)1);

    return Logging_V2::log_profile_event(event);
}

bool Logging_V2::log_profile_exit(oboe_metadata_t* md, pid_t tid, long timestamp, std::vector<long> omitted) {
    Event *event = Logging_V2::createEvent(md);
    event->addInfo((char *)"Label", "exit");
    event->addInfo((char *)"TID", (long)tid);
    event->addInfo((char *)"Timestamp_u", timestamp);
    event->addInfo((char *)"SnapshotsOmitted", omitted);

    return Logging_V2::log_profile_event(event);
}

bool Logging_V2::log_profile_snapshot(oboe_metadata_t *md,
                                      long timestamp,
                                      const std::vector<FrameData> &new_frames,
                                      long exited_frames,
                                      long total_frames,
                                      const std::vector<long> &omitted,
                                      pid_t tid) {
    Event *event = Logging_V2::createEvent(md);
    event->addInfo((char *)"Timestamp_u", timestamp);
    event->addInfo((char *)"Label", "info");
    
    event->addInfo((char *)"SnapshotsOmitted", omitted);
    event->addInfo((char *)"NewFrames", new_frames);
    event->addInfo((char *)"FramesExited", exited_frames);
    event->addInfo((char *)"FramesCount", total_frames);
    event->addInfo((char *)"TID", (long)tid);


    return Logging_V2::log_profile_event(event);
}

bool Logging_V2::log_profile_event(Event *event) {
    event->addInfo((char *)"Spec", "profiling");
    event->addHostname();
    event->addInfo((char *)"PID", (long)AO_GETPID());
    event->addInfo((char *)"X-Trace", event->metadataString());
    event->send_profiling();

    delete event;
    return true;
}
