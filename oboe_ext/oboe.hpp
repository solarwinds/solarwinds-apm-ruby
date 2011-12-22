#ifndef OBOE_HPP
#define OBOE_HPP

#include <string>
#include <oboe/oboe.h>


class Event;

class Metadata : private oboe_metadata_t {
    friend class UdpReporter;
    friend class FileReporter;
    friend class Context;

public:
    Metadata(oboe_metadata_t *md) {
        oboe_metadata_copy(this, md);
    }

    ~Metadata() {
        oboe_metadata_destroy(this);
    }

    static Metadata* fromString(std::string s) {
        oboe_metadata_t md;
        oboe_metadata_fromstr(&md, s.data(), s.size());
        return new Metadata(&md); // copies md
    }

    // these new objects are managed by SWIG %newobject
    Event *createEvent();

    static Metadata *makeRandom() {
        oboe_metadata_t md;
        oboe_metadata_init(&md);
        oboe_metadata_random(&md);
        return new Metadata(&md); // copies md
    }

    Metadata *copy() {
        return new Metadata(this);
    }

    bool isValid() {
        return oboe_metadata_is_valid(this);
    }

#ifdef SWIGJAVA
    std::string toStr() {
#else
    std::string toString() {
#endif
        char buf[MAX_METADATA_PACK_LEN];

        int rc = oboe_metadata_tostr(this, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

};

class Context {
public:
    // returns pointer to current context (from thread-local storage)
    static oboe_metadata_t *get() {
        return oboe_context_get();
    }

#ifdef SWIGJAVA
    static std::string toStr() {
#else
    static std::string toString() {
#endif
        char buf[MAX_METADATA_PACK_LEN];

        oboe_metadata_t *md = Context::get();
        int rc = oboe_metadata_tostr(md, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

    static void set(oboe_metadata_t *md) {
        oboe_context_set(md);
    }

    static void fromString(std::string s) {
        oboe_context_set_fromstr(s.data(), s.size());
    }

    // this new object is managed by SWIG %newobject
    static Metadata *copy() {
        return new Metadata(Context::get());
    }

    static void clear() {
        oboe_context_clear();
    }

    static bool isValid() {
        return oboe_context_is_valid();
    }

    static void init() {
        oboe_init();
    }

    // these new objects are managed by SWIG %newobject
    static Event *createEvent();
    static Event *startTrace();
};

class Event : private oboe_event_t {
    friend class UdpReporter;
    friend class FileReporter;
    friend class Context;
    friend class Metadata;

private:
    Event() {
        oboe_event_init(this, Context::get());
    }

    Event(const oboe_metadata_t *md, bool addEdge=true) {
        // both methods copy metadata from md -> this
        if (addEdge) {
            // create_event automatically adds edge in event to md
            oboe_metadata_create_event(md, this);
        } else {
            // initializes new Event with this md's task_id & new random op_id; no edges set
            oboe_event_init(this, md);
        }
    }

public:
    ~Event() {
        oboe_event_destroy(this);
    }

    // called e.g. from Python e.addInfo("Key", None) & Ruby e.addInfo("Key", nil)
    bool addInfo(char *key, void* val) {
        // oboe_event_add_info(evt, key, NULL) does nothing
        return true;
    }

    bool addInfo(char *key, const std::string& val) {
        if (memchr(val.data(), '\0', val.size())) {
            return oboe_event_add_info_binary(this, key, val.data(), val.size()) == 0;
        } else {
            return oboe_event_add_info(this, key, val.data()) == 0;
        }
    }

    bool addInfo(char *key, long val) {
        int64_t val_ = val;
        return oboe_event_add_info_int64(this, key, val_) == 0;
    }

    bool addInfo(char *key, double val) {
        return oboe_event_add_info_double(this, key, val) == 0;
    }

    bool addEdge(oboe_metadata_t *md) {
        return oboe_event_add_edge(this, md) == 0;
    }

    Metadata* getMetadata() {
        return new Metadata(&this->metadata);
    }

    std::string metadataString() {
        char buf[MAX_METADATA_PACK_LEN];

        int rc = oboe_metadata_tostr(&this->metadata, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

    static Event* startTrace(const oboe_metadata_t *md);

};

Event *Context::createEvent() {
    return new Event(Context::get());
}

Event *Metadata::createEvent() {
    return new Event(this);
}

Event *Context::startTrace() {
    oboe_metadata_t *md = Context::get();
    oboe_metadata_random(md);
    return new Event();
}

Event *Event::startTrace(const oboe_metadata_t *md) {
    return new Event(md, false);
}

class UdpReporter : private oboe_reporter_t {
public:
    UdpReporter(const char *addr, const char *port=NULL) {
        if (port == NULL)
            port = "7831";

        oboe_reporter_udp_init(this, addr, port);
    }

    ~UdpReporter() {
        oboe_reporter_destroy(this);
    }

    bool sendReport(Event *evt) {
        return oboe_reporter_send(this, Context::get(), evt) >= 0;
    }

    bool sendReport(Event *evt, oboe_metadata_t *md) {
        return oboe_reporter_send(this, md, evt) >= 0;
    }
};

class FileReporter : private oboe_reporter_t {
public:
    FileReporter(const char *file) {
        oboe_reporter_file_init(this, file);
    }

    ~FileReporter() {
        oboe_reporter_destroy(this);
    }

    bool sendReport(Event *evt) {
        return oboe_reporter_send(this, Context::get(), evt) >= 0;
    }

    bool sendReport(Event *evt, oboe_metadata_t *md) {
        return oboe_reporter_send(this, md, evt) >= 0;
    }
};
#endif
