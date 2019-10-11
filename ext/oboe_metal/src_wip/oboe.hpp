/**
 * @file oboe.hpp - C++ liboboe wrapper primarily for generating SWIG interfaces
 *
 * This API should follow https://github.com/tracelytics/tracelons/wiki/Instrumentation-API
 */

#ifndef OBOE_HPP
#define OBOE_HPP

#include <string>
#include <iostream>
#include <csignal>
#include <cstdlib>
#include <pthread.h>
#include <unistd.h>

#include <oboe.h>

#include <ruby.h>
#include <ruby/debug.h>

#include <sys/time.h>

long long current_timestamp() {
    struct timeval te; 
    gettimeofday(&te, NULL); // get current time
    long long milliseconds = te.tv_sec*1000LL + te.tv_usec/1000; // calculate milliseconds
    // printf("milliseconds: %lld\n", milliseconds);
    return milliseconds;
}

// #include "../ruby_headers/vm_core.h"
// NOT working, compile errors

// #if defined HAVE_UINTPTR_T && 0
// typedef uintptr_t VALUE;
// #elif SIZEOF_LONG == SIZEOF_VOIDP
// typedef unsigned long VALUE;
// #elif SIZEOF_LONG_LONG == SIZEOF_VOIDP
// typedef unsigned LONG_LONG VALUE;
// #else
// # error ---->> ruby requires sizeof(void*) == sizeof(long) or sizeof(LONG_LONG) to be compiled. <<----
// #endif
//
// #ifdef __cplusplus
// extern "C"
// #else
// extern
// #endif
// {
//  VALUE rb_thread_backtrace_m(int argc, VALUE *argv, VALUE thval);
// }
// NOT working can't find symbol for rb_thread_backtrace_m 


class Event;
class Reporter;
class Context;

/**
 * Metadata is the X-Trace identifier and the information needed to work with it.
 */
class Metadata : private oboe_metadata_t {
    friend class Reporter;
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

    static Metadata *makeRandom(bool sampled=true) {
        oboe_metadata_t md;
        oboe_metadata_init(&md);
        oboe_metadata_random(&md);

        if (sampled) {
            md.flags |= XTR_FLAGS_SAMPLED;
        }

        return new Metadata(&md); // copies md
    }

    Metadata *copy() {
        return new Metadata(this);
    }

    bool isValid() {
        return oboe_metadata_is_valid(this);
    }

    bool isSampled() {
        return oboe_metadata_is_sampled(this);
    }

#ifdef SWIGJAVA
    std::string toStr() {
#else
    std::string toString() {
#endif
        char buf[OBOE_MAX_METADATA_PACK_LEN]; // Flawfinder: ignore

        int rc = oboe_metadata_tostr(this, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

};

/**
 * The Context class manages the metadata and the settings configuration.
 *
 * The metadata includes the X-Trace identifier fields and the information work working with it.
 * The metadata is needed before any trace messages can be sent and must either be generated for
 * new traces or derived from the X-Trace header of an existing trace.
 *
 * The settings information is used primarily to determine when a new request should be traced.
 * The information begins with configuration values for tracing_mode and sample_rate and then
 * updates are received periodically from the collector to adjust the rate at which traces
 * are generated.
 */
class Context {
public:
    /**
     * Set the tracing mode.
     *
     * @param newMode One of
     * - OBOE_TRACE_DISABLED(0) to disable tracing,
     * - OBOE_TRACE_ENABLED(1) to start a new trace if needed, or
     * - OBOE_TRACE_THROUGH(2) to only add to an existing trace.
     */
    static void setTracingMode(int newMode) {
        oboe_settings_mode_set(newMode);
    }

    /**
     * Set the default sample rate.
     *
     * This rate is used until overridden by the AppOptics servers.  If not set then the
     * value comes from settings records downloaded from AppOptics.
     *
     * The rate is interpreted as a ratio out of OBOE_SAMPLE_RESOLUTION (currently 1,000,000).
     *
     * @param newRate A number between 0 (none) and OBOE_SAMPLE_RESOLUTION (a million)
     */
    static void setDefaultSampleRate(int newRate) {
        oboe_settings_rate_set(newRate);
    }

    /**
     * Ask the collector for the final tracing decisions
     *
     * call once per request
     *
     * when compiled via SWIG this function takes 0-8 input argss and returns 9 output args
     *
     * inputs (0-8, all optional):
     * @param in_xtrace, a valid xtrace string
     * @param custom_sample_rate, 0-1000000
     * @param custom_tracing_mode, 0(disabled) or 1(enabled)
     * @param request_type, 0 normal sampling, 1 trigger trace
     * @param custom_custom_trigger_mode, 0(disabled) or 1(enabled) 
     * @param header_options, the string from the X-Trace-Options header
     * @param header_signature, the string from the X-Trace-Options-Signature header 
     * @param header_timestamp, the timestamp insidethe X-Trace-Options header 
     * 
     * returns:
     * @param do_metrics, ignore when using SWIG, it will be mapped to the second return value
     * @param do_sample, ignore when using SWIG, it will be mapped to the first return value
     * @param sample_rate, ignore when using SWIG, it will be mapped to the third return value
     * @param sample_source, ignore when using SWIG, it will be mapped to the forth return value
     * @param type, 0 normal sampling, 1 - trigger trace
     * @param auth, 0 success, 1 failure, -1 not requested
     * @param status_msg, message describing the trigger tracing decision
     * @param auth_msg, message describing the succes/failure of the authorization
     * 
     * @status one of the OBOE_TRACING_DECISION_* codes
     */

    static void getDecisions(int *do_metrics, int *do_sample, int *sample_rate, int *sample_source, 
                             int *type, int *auth, 
                             std::string *status_msg, std::string *auth_msg, 
                             int *status,
                             const char *in_xtrace = NULL,
                             int custom_tracing_mode = OBOE_SETTINGS_UNSET,
                             int custom_sample_rate = OBOE_SETTINGS_UNSET, 
                             int request_type = 0,
                             int custom_trigger_mode = 0,
                             const char *header_options = NULL,
                             const char *header_signature = NULL,
                             long header_timestamp = 0 
                             )  {

        oboe_tracing_decisions_in_t tdi;
        memset(&tdi, 0, sizeof(tdi));
        tdi.custom_tracing_mode = custom_tracing_mode;
        tdi.custom_sample_rate = custom_sample_rate;
        tdi.custom_trigger_mode = custom_trigger_mode;
        tdi.request_type = request_type;
        tdi.version = 2;
        tdi.in_xtrace = in_xtrace;
        tdi.header_options = header_options;
        tdi.header_signature = header_signature;
        tdi.header_timestamp = header_timestamp;

        oboe_tracing_decisions_out_t tdo;
        memset(&tdo, 0, sizeof(tdo));
        tdo.version = 2;

        *status = oboe_tracing_decisions(&tdi, &tdo);

       // TODO this can be removed once everything is debugged
       if (std::getenv("OBOE_VERBOSE")) { // Flawfinder: ignore
            std::cout << "- - - - - - - - - - - - - - - - - -" << std::endl;
            std::cout << "Decisions in: " << std::endl;
       
            std::cout << "version " << tdi.version << std::endl;
            if (tdi.service_name) { std::cout << "service_name " << tdi.service_name << std::endl; }
            if (tdi.in_xtrace) { std::cout << "in_xtrace " << tdi.in_xtrace << std::endl; }
            std::cout << "custom_sample_rate " << tdi.custom_sample_rate << std::endl;
            std::cout << "custom_tracing_mode " << tdi.custom_tracing_mode << std::endl;
            std::cout << "custom_trigger_mode " << tdi.custom_trigger_mode << std::endl;
            std::cout << "request_type " << tdi.request_type << std::endl;
            if (tdi.header_options) { std::cout << "header_options " << tdi.header_options << std::endl; }
            if (tdi.header_signature) { std::cout << "header_signature " << tdi.header_signature << std::endl; }
            std::cout << "header_timestamp " << tdi.header_timestamp << std::endl;

            std::cout << std::endl;
            std::cout << "Decisions out: " << std::endl;

            std::cout << "version " << tdo.version << std::endl;
            std::cout << "sample_rate " << tdo.sample_rate << std::endl;
            std::cout << "sample_source " << tdo.sample_source << std::endl;
            std::cout << "do_sample " << tdo.do_sample << std::endl;
            std::cout << "do_metrics " << tdo.do_metrics << std::endl;
            std::cout << "request_provisioned " << tdo.request_provisioned << std::endl;
            std::cout << "auth_status " << tdo.auth_status << std::endl;
            std::cout << "auth_message " << tdo.auth_message << std::endl;
            std::cout << "status_message " << tdo.status_message << std::endl;

            std::cout << std::endl << "status is " << *status << std::endl;
            std::cout << "- - - - - - - - - - - - - - - - - -" << std::endl;
       }
        
        *do_sample = tdo.do_sample;
        *do_metrics = tdo.do_metrics;
        *sample_rate = tdo.sample_rate;
        *sample_source = tdo.sample_source;
        *type = tdo.request_provisioned;
        if (tdo.status_message && tdo.status_message[0] != '\0') {
            *status_msg = tdo.status_message;
        }
        *auth = tdo.auth_status;
        if (tdo.auth_message && tdo.auth_message[0] != '\0') {
            *auth_msg = tdo.auth_message;
        }
    }

    /**
     * Get a pointer to the current context (from thread-local storage)
     */
    static oboe_metadata_t *get() {
        return oboe_context_get();
    }

    /**
     * Get the current context as a printable string.
     */
#ifdef SWIGJAVA
    static std::string toStr() {
#else
    static std::string toString() {
#endif
        char buf[OBOE_MAX_METADATA_PACK_LEN]; // Flawfinder: ignore

        oboe_metadata_t *md = Context::get();
        int rc = oboe_metadata_tostr(md, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

    /**
     * Set the current context (this updates thread-local storage).
     */
    static void set(oboe_metadata_t *md) {
        oboe_context_set(md);
    }

    /**
     * Set the current context from a string.
     */
    static void fromString(std::string s) {
        oboe_context_set_fromstr(s.data(), s.size());
    }

    // this new object is managed by SWIG %newobject
    static Metadata *copy() {
        return new Metadata(Context::get());
    }

    static void setSampledFlag() {
        oboe_metadata_t *md = Context::get();
        md->flags |= XTR_FLAGS_SAMPLED;
    }

    static void clear() {
        oboe_context_clear();
    }

    static bool isValid() {
        return oboe_context_is_valid();
    }

    static bool isSampled() {
        return oboe_context_is_sampled();
    }

  /**
   * Initialize the Oboe subsystems.
   *
   * This should be called before any other oboe_* functions.  However, in order
   * to make the library easier to work with, checks are in place so that it
   * will be called by any of the other functions that depend on it.
   *
   * Besides initializing the oboe library, this will also initialize a
   * reporter based on the values of environment variables, configuration
   * file options.  See the oboe_init_options struct definition in oboe.h
   * for details on the full set of options.
   *
     * @param access_key Client access key
     * @param hostname_alias An optional logical/readable hostname that can be used to easily identify the host
     * @param log_level Optional parameter to configure the log level for messages logged by oboe
     * @param max_flush_wait_time Optional parameter to configure maximum wait time for flushing data before terminating in milli seconds
     * @param events_flush_interval Optional parameter to configure how frequently events are flushed
     * @param events_flush_batch_size Optional parameter to configure the batch size before events are flushed
     * @param ec2_metadata_timeout Optional parameter to configure the timeout (milli seconds) for retrieving EC2 metadata
   */
    static void init(std::string access_key = "", std::string hostname_alias = "",
            int log_level = LOGLEVEL_DEFAULT,
            int max_flush_wait_time = DEFAULT_FLUSH_MAX_WAIT_TIME,
            int events_flush_interval = OBOE_DEFAULT_EVENTS_FLUSH_INTERVAL,
            int events_flush_batch_size = OBOE_DEFAULT_EVENTS_FLUSH_BATCH_SIZE,
            int ec2_metadata_timeout = OBOE_DEFAULT_EC2_METADATA_TIMEOUT) {
        oboe_init_options_t options;
        memset(&options, 0, sizeof(options));
        options.version = 7;
        options.log_level = log_level;
        options.hostname_alias = hostname_alias.c_str();
        options.max_flush_wait_time = max_flush_wait_time;
        options.events_flush_interval = events_flush_interval;
        options.events_flush_batch_size = events_flush_batch_size;
        options.ec2_metadata_timeout = ec2_metadata_timeout;

        oboe_init(&options);
   }

    /**
     * Perform validation and replacement of invalid characters on the given service key.
     */
    static std::string validateTransformServiceName(std::string service_key) {
        char service_key_cpy[71 + 1 + 256]; // Flawfinder: ignore, key=71, colon=1, name<=255
        memset(service_key_cpy, 0, sizeof(service_key_cpy));
        strncpy(service_key_cpy, service_key.c_str(), sizeof(service_key_cpy) - 1); // Flawfinder: ignore
        int len = strlen(service_key_cpy); // Flawfinder: ignore
        int ret = oboe_validate_transform_service_name(service_key_cpy, &len);

        if (ret == -1) {
            return "";
        }

        return std::string(service_key_cpy);
    }

    /**
     * Shut down the Oboe library.
     *
     * This releases any resources held by the library which may include terminating
     * child threads.
     */
    static void shutdown() {
        oboe_shutdown();
    }

    /**
     * check if oboe is ready for tracing
     *
     * @param timeout an optional timeout (in milli seconds) to block this function until ready
     * @return one of the return codes (see oboe.h):
     * - OBOE_SERVER_RESPONSE_UNKNOWN
     * - OBOE_SERVER_RESPONSE_OK
     * - OBOE_SERVER_RESPONSE_TRY_LATER
     * - OBOE_SERVER_RESPONSE_LIMIT_EXCEEDED
     * - OBOE_SERVER_RESPONSE_INVALID_API_KEY
     * - OBOE_SERVER_RESPONSE_CONNECT_ERROR
     */
    static int isReady(unsigned int timeout) {
        return oboe_is_ready(timeout);
    }

    // these new objects are managed by SWIG %newobject
    static Event *createEvent();
    static Event *startTrace();

private:

};

class Event : private oboe_event_t {
    friend class Reporter;
    friend class Context;
    friend class Metadata;

private:
    Event() {
        oboe_event_init(this, Context::get(), NULL);
    }

    Event(const oboe_metadata_t *md, bool addEdge=true) {
        // both methods copy metadata from md -> this
        if (addEdge) {
            // create_event automatically adds edge in event to md
            oboe_metadata_create_event(md, this);
        } else {
            // initializes new Event with this md's task_id & new random op_id; no edges set
            oboe_event_init(this, md, NULL);
        }
    }

public:
    ~Event() {
        oboe_event_destroy(this);
    }

    // called e.g. from Python e.addInfo("Key", None) & Ruby e.addInfo("Key", nil)
    bool addInfo(char *key, void* val) {
        // oboe_event_add_info(evt, key, NULL) does nothing
        (void) key;
        (void) val;
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

    bool addEdgeStr(const std::string& val) {
        return oboe_event_add_edge_fromstr(this, val.c_str(), val.size()) == 0;
    }

    /**
     * Get a new copy of this metadata.
     *
     * NOTE: The returned object must be "delete"d.
     */
    Metadata* getMetadata() {
        return new Metadata(&this->metadata);
    }

    std::string metadataString() {
        char buf[OBOE_MAX_METADATA_PACK_LEN]; // Flawfinder: ignore

        int rc = oboe_metadata_tostr(&this->metadata, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

    /**
     * Report this event.
     *
     * This sends the event using the default reporter.
     *
     * @return True on success; otherwise an error message is logged.
     */
    bool send() {
        return (oboe_event_send(OBOE_SEND_EVENT, this, Context::get()) >= 0);
    }

    static Event* startTrace(const oboe_metadata_t *md);

};

class Span {
public:
    static std::string createSpan(const char *transaction, const char *domain, const int64_t duration, const char *service_name = NULL);

    static std::string createHttpSpan(const char *transaction, const char *url, const char *domain, const int64_t duration,
            const int status, const char *method, const int has_error, const char *service_name = NULL);
};

std::string Span::createSpan(const char *transaction, const char *domain, const int64_t duration, const char *service_name) {
    oboe_span_params_t params;
    memset(&params, 0, sizeof(oboe_span_params_t));
    params.version = 1;
    params.transaction = transaction;
    params.domain = domain;
    params.duration = duration;
    params.service = service_name;

    char buffer[OBOE_TRANSACTION_NAME_MAX_LENGTH + 1]; // Flawfinder: ignore
    int len = oboe_span(buffer, sizeof(buffer), &params);
    if (len > 0) {
        return std::string(buffer);
    } else {
        return "";
    }
}

std::string Span::createHttpSpan(const char *transaction, const char *url, const char *domain, const int64_t duration,
        const int status, const char *method, const int has_error, const char *service_name) {
    oboe_span_params_t params;
    memset(&params, 0, sizeof(oboe_span_params_t));
    params.version = 1;
    params.transaction = transaction;
    params.url = url;
    params.domain = domain;
    params.duration = duration;
    params.status = status;
    params.method = method;
    params.has_error = has_error;
    params.service = service_name;

    char buffer[OBOE_TRANSACTION_NAME_MAX_LENGTH + 1]; // Flawfinder: ignore
    int len = oboe_http_span(buffer, sizeof(buffer), &params);
    if (len > 0) {
        return std::string(buffer);
    } else {
        return "";
    }
}

class MetricTags {
    friend class CustomMetrics;
public:
    MetricTags(size_t count) {
        tags = new oboe_metric_tag_t[count];
        size = count;
    }
    ~MetricTags() {
        delete[] tags;
    }
    bool add(size_t index, char *k, char *v) {
        if (index < size) {
            tags[index].key = k;
            tags[index].value = v;
            return true;
        }
        return false;
    }
private:
    oboe_metric_tag_t* get() const {
        return tags;
    }

    oboe_metric_tag_t *tags;
    size_t size;
};

class CustomMetrics {
public:
    static int summary(const char *name, const double value, const int count, const int host_tag,
            const char *service_name, const MetricTags *tags, size_t tags_count) {
        if (tags->size < tags_count) {
            tags_count = tags->size;
        }
        return oboe_custom_metric_summary(name, value, count, host_tag, service_name, tags->get(), tags_count);
    }

    static int increment(const char *name, const int count, const int host_tag,
            const char *service_name, const MetricTags *tags, size_t tags_count) {
        if (tags->size < tags_count) {
            tags_count = tags->size;
        }
        return oboe_custom_metric_increment(name, count, host_tag, service_name, tags->get(), tags_count);
    }
};

/**
 * Create a new event object using the thread's context.
 *
 * NOTE: The returned object must be "delete"d.
 */
Event *Context::createEvent() {
    return new Event(Context::get());
}

/**
 * Create a new event object using this Metadata's context.
 *
 * NOTE: The returned object must be "delete"d.
 */
Event *Metadata::createEvent() {
    return new Event(this);
}

/**
 * Create a new event object with a new trace context.
 *
 * NOTE: The returned object must be "delete"d.
 */
Event *Context::startTrace() {
    oboe_metadata_t *md = Context::get();
    oboe_metadata_random(md);
    return new Event();
}

/**
 * Create a new event object using the given metadata context.
 *
 * NOTE: The metadata context must be unique to the new trace.
 *
 * NOTE: The returned object must be "delete"d.
 *
 * @param md The metadata object to use when creating the new event.
 */
Event *Event::startTrace(const oboe_metadata_t *md) {
    return new Event(md, false);
}

static struct {
    VALUE buff[2048];
    int lines[2048];
} _stack;

class Reporter : private oboe_reporter_t {
    friend class Context;   // Access to the private oboe_reporter_t base structure.
public:

    int init_status;

    /**
     * Initialize a reporter structure.
     *
     * See the wrapped Context::init for more details.
     *
     * @params  these correspond to the keys of the oboe_init_options struct
     */
    Reporter(
             std::string hostname_alias,     // optional hostname alias
             int log_level,                  // level at which log messages will be written to log file (0-6)
             std::string log_file_path,      // file name including path for log file

             int max_transactions,           // maximum number of transaction names to track
             int max_flush_wait_time,        // maximum wait time for flushing data before terminating in milli seconds
             int events_flush_interval,      // events flush timeout in seconds (threshold for batching messages before sending off)
             int events_flush_batch_size,    // events flush batch size in KB (threshold for batching messages before sending off)


             std::string reporter,           // the reporter to be used ("ssl", "upd", "file", "null")
             std::string host,               // collector endpoint (reporter=ssl), udp address (reporter=udp), or file path (reporter=file)
             std::string service_key,        // the service key (also known as access_key)
             std::string trusted_path,       // path to the SSL certificate (only for ssl)

             int buffer_size,                // size of the message buffer
             int trace_metrics,              // flag indicating if trace metrics reporting should be enabled (default) or disabled
             int histogram_precision,        // the histogram precision (only for ssl)
             int token_bucket_capacity,      // custom token bucket capacity
             int token_bucket_rate,          // custom token bucket rate
             int file_single,                // use single files in file reporter for each event

             int ec2_metadata_timeout        // the timeout (milli seconds) for retrieving EC2 metadata
             ) {

        oboe_init_options_t options;
        memset(&options, 0, sizeof(options));
        options.version = 7;
        oboe_init_options_set_defaults(&options);

        if (hostname_alias != "") {
            options.hostname_alias = hostname_alias.c_str();
        }
        options.log_level = log_level;
        options.log_file_path = log_file_path.c_str();
        options.max_transactions = max_transactions;
        options.max_flush_wait_time = max_flush_wait_time;
        options.events_flush_interval = events_flush_interval;
        options.events_flush_batch_size = events_flush_batch_size;
        if (reporter != "") {
            options.reporter = reporter.c_str();
        }
        if (host != "") {
            options.host = host.c_str();
        }
        if (service_key != "") {
            options.service_key = service_key.c_str();
        }
        if (trusted_path != "") {
            options.trusted_path = trusted_path.c_str();
        }
        options.buffer_size = buffer_size;
        options.trace_metrics = trace_metrics;
        options.histogram_precision = histogram_precision;
        options.token_bucket_capacity = token_bucket_capacity;
        options.token_bucket_rate = token_bucket_rate;
        options.file_single = file_single;
        options.ec2_metadata_timeout = ec2_metadata_timeout;

        init_status = oboe_init(&options);
    }

    ~Reporter() {
        oboe_reporter_destroy(this);
    }

    bool sendReport(Event *evt) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, Context::get()) >= 0;
    }

    bool sendReport(Event *evt, oboe_metadata_t *md) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, md) >= 0;
    }

    bool sendStatus(Event *evt) {
        return oboe_event_send(OBOE_SEND_STATUS, evt, Context::get()) >= 0;
    }

    bool sendStatus(Event *evt, oboe_metadata_t *md) {
        return oboe_event_send(OBOE_SEND_STATUS, evt, md) >= 0;
    }

    void profile_thread() {
        
        pthread_t t;
        pthread_create(&t, NULL, profiling, NULL);

 
        // VALUE x;
        // x = rb_str_new_cstr("Hello, world!");
        std::cout << "going to sleep" << std::endl;
        usleep(5000);
    }

    static void sample_frames() {
        // std::cout << "in sample_frames" << std::endl;
        while (rb_during_gc()) {
            std::cout << "ruby gc ... ";
            usleep(10);
        }
        
        int num = rb_profile_frames(0, sizeof(_stack.buff)/sizeof(VALUE), _stack.buff, _stack.lines);
        for (int i = 0; i < num-1; i++) {
            VALUE path = rb_profile_frame_absolute_path(_stack.buff[i]);  // USE for path
            // VALUE frame = rb_profile_frame_path(_stack.buff[i]);   // don't know yet
            // VALUE abs_path = rb_profile_frame_absolute_path(_stack.buff[i]); // don't know yet
            // VALUE label = rb_profile_frame_label(_stack.buff[i]);        // Maybe use
            // VALUE base_label = rb_profile_frame_base_label(_stack.buff[i]); // don't know yet
            // VALUE full_label = rb_profile_frame_full_label(_stack.buff[i]); // don't know yet
            // VALUE lineno = rb_profile_frame_first_lineno(_stack.buff[i]); // hopefully USE 
            VALUE classpath = rb_profile_frame_classpath(_stack.buff[i]); // don't know yet
            // VALUE class_method_p= rb_profile_frame_singleton_method_p(_stack.buff[i]); // don't know yet
            VALUE method = rb_profile_frame_method_name(_stack.buff[i]); // don't know yet 
            // VALUE method_name = rb_profile_frame_qualified_method_name(_stack.buff[i]); // don't know yet

            std::cout << std::endl << i << ":" << std::endl;
            if (RB_TYPE_P(path, T_STRING)) std::cout << StringValuePtr(path);
            std::cout << std::endl;
            // if (RB_TYPE_P(frame, T_STRING)) std::cout << StringValuePtr(frame);
            // std::cout << std::endl;
            // if (RB_TYPE_P(abs_path, T_STRING)) std::cout << StringValuePtr(abs_path);
            // std::cout << std::endl;
            // if (RB_TYPE_P(label, T_STRING)) std::cout << StringValuePtr(label);
            // std::cout << std::endl;
            // if (RB_TYPE_P(base_label, T_STRING)) std::cout << StringValuePtr(base_label);
            // std::cout << std::endl;
            // if (RB_TYPE_P(full_label, T_STRING)) std::cout << StringValuePtr(full_label);
            // std::cout << std::endl;
            // if (RB_TYPE_P(lineno, T_FIXNUM)) std::cout << FIX2LONG(lineno);
            std::cout << _stack.lines[i] << std::endl; 
            if (RB_TYPE_P(classpath, T_STRING)) std::cout << StringValuePtr(classpath);
            // else std::cout << TYPE(classpath);  // 17 = nil
            std::cout << std::endl;
            // if (RB_TYPE_P(class_method_p, T_STRING)) std::cout << StringValuePtr(class_method_p);
            // else std::cout << TYPE(class_method_p); // 19 = false 
            // std::cout << std::endl;
            if (RB_TYPE_P(method, T_STRING)) std::cout << StringValuePtr(method);
            // else std::cout << TYPE(method); // 17 = nil
            std::cout << std::endl;
            // if (RB_TYPE_P(method_name, T_STRING)) std::cout << StringValuePtr(method_name);
            // else std::cout << TYPE(method_name); // 17 = nil
            
            // std::cout << StringValuePtr(method) << num << std::endl;
        }

        // VALUE frame = _stack.buff[0];
        // type of frame is T_IMEMO / RBU_T_IMEMO 

        // VALUE x;
        // x = rb_str_new_cstr("\nHello, world!");
        std::cout << std::endl << "Num Lines " << num << std::endl;

        // if (RB_TYPE_P(frame, T_STRING)) {
            // std::cout << "it's a string" << std::endl;
        // }

        // std::cout << StringValuePtr(frame) << std::endl;
    }
    

    static void *profiling(void *) {
        std::cout << "in profiling" << std::endl;
        // int sig = 29;
        // std::signal(sig, sample_frames);

        for (;;) {
            usleep(20000);
            sample_frames();
            std::cout << current_timestamp() << std::endl;
        }
        std::cout << "done" << std::endl;
                // rb_thread_backtrace_m(1, NULL, 1);
                // get ruby thread(s)
                // run loop every x milliseconds
                //    capture backtrace
                //    print (some) backtrace

                // loop do prev = [] omitted =
                //     [] if @queue.pop == 'go' send_start started =
                //         true while @queue.empty
                //     ? do start = Time.now puts "#{start.nsec/1000}" backtrace
                //     =
                //           @parent.backtrace #.reject{
                //               | entry | entry = ~ /`block(\(\d + levels\))
                //               ? in / } omitted = send_snapshot(backtrace,
                //               prev, omitted,
                //                                                start) prev =
                //                                                backtrace

                //                     sleep_secs =
                //                         @interval -
                //                             (Time.now - start)
                //                                 .to_f
                //                                 Oboe_metal::Reporter.msSleep(
                //                                     (sleep_secs * 1000)
                //                                         .to_i) if sleep_secs
                //                                         >
                //                         0 end if started omitted =
                //                             send_end(omitted) started =
                //                                 false end @queue.pop
                //                                 @response_queue
                //                                 << 'done' end end ensure
                //                                 send_end(
                //                                        omitted) if @started
                //                                        end
                return NULL;
    }
};

/**
 * Base class for a diagnostic log message handler.
 */
class DebugLogger {
public:
    virtual ~DebugLogger() {}
    virtual void log(int module, int level, const char *source_name, int source_lineno, const char *msg) = 0;
};

/**
 * "C" language wrapper for DebugLogger classes.
 *
 * A logging function that can be added to the logger chain using
 * DebugLog::addDebugLogger().
 *
 * @param context The context pointer that was registered in the call to
 *          DebugLog::addDebugLogger().  Use it to pass the pointer-to-self for
 *          objects (ie. "this" in C++) or just a structure in C,  May be
 *          NULL.
 * @param module The module identifier as passed to oboe_debug_logger().
 * @param level The diagnostic detail level as passed to oboe_debug_logger().
 * @param source_name Name of the source file as passed to oboe_debug_logger().
 * @param source_lineno Number of the line in the source file where message is
 *          logged from as passed to oboe_debug_logger().
 * @param msg The formatted message produced from the format string and its
 *          arguments as passed to oboe_debug_logger().
 */
extern "C" void oboe_debug_log_handler(void *context, int module, int level, const char *source_name, int source_lineno, const char *msg) {
    ((DebugLogger *)context)->log(module, level, source_name, source_lineno, msg);
}

class DebugLog {
public:
    /**
     * Get a printable name for a diagnostics logging level.
     *
     * @param level A detail level in the range 0 to 6 (OBOE_DEBUG_FATAL to OBOE_DEBUG_HIGH).
     */
    static std::string getLevelName(int level) {
        return std::string(oboe_debug_log_level_name(level));
    }

    /**
     * Get a printable name for a diagnostics logging module identifier.
     *
     * @param module One of the OBOE_MODULE_* values.
     */
    static std::string getModuleName(int module) {
        return std::string(oboe_debug_module_name(module));
    }

    /**
     * Get the maximum logging detail level for a module or for all modules.
     *
     * This level applies to the default logger only.  Added loggers get all messages
     * below their registed detail level and need to do their own module-specific
     * filtering.
     *
     * @param module One of the OBOE_MODULE_* values.  Use OBOE_MODULE_ALL (-1) to
     *          get the overall maximum detail level.
     * @return Maximum detail level value for module (or overall) where zero is the
     *          lowest and higher values generate more detailed log messages.
     */
    static int getLevel(int module) {
        return oboe_debug_log_level_get(module);
    }

    /**
     * Set the maximum logging detail level for a module or for all modules.
     *
     * This level applies to the default logger only.  Added loggers get all messages
     * below their registered detail level and need to do their own module-specific
     * filtering.
     *
     * @param module One of the OBOE_MODULE_* values.  Use OBOE_MODULE_ALL to set
     *          the overall maximum detail level.
     * @param newLevel Maximum detail level value where zero is the lowest and higher
     *          values generate more detailed log messages.
     */
    static void setLevel(int module, int newLevel) {
        oboe_debug_log_level_set(module, newLevel);
    }

    /**
     * Set the output stream for the default logger.
     *
     * @param newStream A valid, open FILE* stream or NULL to disable the default logger.
     * @return Zero on success; otherwise an error code (normally from errno).
     */
    static int setOutputStream(FILE *newStream) {
        return oboe_debug_log_to_stream(newStream);
    }

    /**
     * Set the default logger to write to the specified file.
     *
     * A NULL or empty path name will disable the default logger.
     *
     * If the file exists then it will be opened in append mode.
     *
     * @param pathname The path name of the
     * @return Zero on success; otherwise an error code (normally from errno).
     */
    static int setOutputFile(const char *pathname) {
        return oboe_debug_log_to_file(pathname);
    }

    /**
     * Add a logger that takes messages up to a given logging detail level.
     *
     * This adds the logger to a chain in order of the logging level.  Log messages
     * are passed to each logger down the chain until the remaining loggers only
     * accept messages of a lower detail level.
     *
     * @return Zero on success, one if re-registered with the new logging level, and
     *          otherwise a negative value to indicate an error.
     */
    static int addDebugLogger(DebugLogger *newLogger, int logLevel) {
        return oboe_debug_log_add(oboe_debug_log_handler, newLogger, logLevel);
    }

    /**
     * Remove a logger.
     *
     * Remove the logger from the message handling chain.
     *
     * @return Zero on success, one if it was not found, and otherwise a negative
     *          value to indicate an error.
     */
    static int removeDebugLogger(DebugLogger *oldLogger) {
        return oboe_debug_log_remove(oboe_debug_log_handler, oldLogger);
    }

    /**
     * Low-level diagnostics logging function.
     *
     * Use this to pass
     * @param module One of the numeric module identifiers defined in debug.h - used to control logging detail by module.
     * @param level Diagnostic detail level of this message - used to control logging volume by detail level.
     * @param source_name Name of the source file, if available, or another useful name, or NULL.
     * @param source_lineno Number of the line in the source file where message is logged from, if available, or zero.
     * @param format A C language printf format specification string.
     * @param args A variable argument list in VA_ARG format containing arguments for each argument specifier in the format.
     */
    static void logMessage(int module, int level, const char *source_name, int source_lineno, const char *msg) {
        oboe_debug_logger(module, level, source_name, source_lineno, "%s", msg);
    }
};

class Config {
public:
    /**
     * Check if the Oboe library is compatible with a given version.revision.
     *
     * This will succeed if the library is at least as recent as specified and if no
     * definitions have been removed since that revision.
     *
     * @param version The library's version number which increments every time the API changes.
     * @param revision The revision of the current version of the library.
     * @return Non-zero if the Oboe library is considered compatible with the specified revision.
     */
    static bool checkVersion(int version, int revision) {
        return (oboe_config_check_version(version, revision) != 0);
    }

    /**
     * Get the Oboe library version number.
     *
     * This number increments whenever an incompatible change to the API/ABI is made.
     *
     * @return The library's version number or -1 if the version is not known.
     */
    static int getVersion() {
        return oboe_config_get_version();
    }

    /**
     * Get the Oboe library revision number.
     *
     * This number increments whenever a compatible change is made to the
     * API/ABI (ie. an addition).
     *
     * @return The library's revision number or -1 if not known.
     */
    static int getRevision() {
        return oboe_config_get_revision();
    }
};

#endif      // OBOE_HPP
