/**
 * @file oboe.hpp - C++ liboboe wrapper primarily for generating SWIG interfaces
 *
 * This API should follow https://github.com/tracelytics/tracelons/wiki/Instrumentation-API
 */

#ifndef OBOE_HPP
#define OBOE_HPP

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <unistd.h>
#include <assert.h>
#include <vector>

#include "oboe.h"
#include "profiling.h"

class Event;
class Reporter;
class Context;

void oboe_btoh(const uint8_t *bytes, char *str, size_t len);

typedef struct frame_info {
    std::string klass;
    std::string method;
    std::string file;
    int lineno;
} frame_t;

/**
 * Metadata is the X-Trace identifier and the information needed to work with it.
 */
class Metadata : private oboe_metadata_t {
    friend class Reporter;
    friend class Context;

public:
    Metadata(oboe_metadata_t *md);
    ~Metadata();

    // these new objects are managed by SWIG %newobject
    /**
     * Create a new event object using this Metadata's context.
     *
     * NOTE: The returned object must be "delete"d.
     */
    Event *createEvent();

    Metadata *copy();
    bool isValid();
    bool isSampled();

    static Metadata *makeRandom(bool sampled = true);
    static Metadata* fromString(std::string s);

#ifdef SWIGJAVA
    std::string toStr();
#else
    std::string toString();
#endif
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
    static void setTracingMode(int newMode);

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
    static void setDefaultSampleRate(int newRate);

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
     * @param header_timestamp, the timestamp inside the X-Trace-Options header
     *
     * returns:
     * @param do_metrics, ignore when using SWIG, it will be mapped to the first return value
     * @param do_sample, ignore when using SWIG, it will be mapped to the second return value
     * @param sample_rate, ignore when using SWIG, it will be mapped to the third return value
     * @param sample_source, ignore when using SWIG, it will be mapped to the forth return value
     * @param type, 0 normal sampling, 1 - trigger trace
     * @param auth, 0 success, 1 failure, -1 not requested
     * @param status_msg, message describing the trigger tracing decision
     * @param auth_msg, message describing the success/failure of the authorization
     *
     * @status one of the OBOE_TRACING_DECISION_* codes
     */

    static void getDecisions(
			// output
			int *do_metrics,
			int *do_sample,
			int *sample_rate,
			int *sample_source,
			int *type,
			int *auth,
			std::string *status_msg,
			std::string *auth_msg,
			int *status,
			// input
			const char *in_xtrace = NULL,
			int custom_tracing_mode = OBOE_SETTINGS_UNSET,
			int custom_sample_rate = OBOE_SETTINGS_UNSET,
			int request_type = 0,
			int custom_trigger_mode = 0,
			const char *header_options = NULL,
			const char *header_signature = NULL,
			long header_timestamp = 0
    );

    /**
     * Get a pointer to the current context (from thread-local storage)
     */
    static oboe_metadata_t *get();

    /**
     * Get the current context as a printable string.
     */
#ifdef SWIGJAVA
    static std::string toStr();
#else
    static std::string toString();
#endif

    /**
     * Set the current context (this updates thread-local storage).
     */
    static void set(oboe_metadata_t *md);

    /**
     * Set the current context from a string.
     */
    static void fromString(std::string s);

    // this new object is managed by SWIG %newobject
    static Metadata *copy();

    static void setSampledFlag();

    static void clear();

    static bool isValid();

    static bool isSampled();

    /**
     * Perform validation and replacement of invalid characters on the given service key.
     */
    static std::string validateTransformServiceName(std::string service_key);

    /**
     * Shut down the Oboe library.
     *
     * This releases any resources held by the library which may include terminating
     * child threads.
     */
    static void shutdown();

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
    static int isReady(unsigned int timeout);

    // these new objects are managed by SWIG %newobject
    /**
     * Create a new event object using the thread's context.
     *
     * NOTE: The returned object must be "delete"d.
     */
    static Event *createEvent();
    static Event *startTrace();
};

class Event : private oboe_event_t {
    friend class Reporter;
    friend class Context;
    friend class Metadata;

private:
    Event();
    Event(const oboe_metadata_t *md, bool addEdge = true);

public:
    ~Event();

    // called e.g. from Python e.addInfo("Key", None) & Ruby e.addInfo("Key", nil)
    bool addInfo(char *key, void* val);
    bool addInfo(char *key, const std::string &val);
    bool addInfo(char *key, long val);
    bool addInfo(char *key, double val);
    bool addInfo(char *key, const std::vector<long> &val);
    bool addInfo(char*, long *val, int num);
    bool addInfo(char *key, const std::vector<frame_t> &val, int num);

    bool addEdge(oboe_metadata_t *md);
    bool addEdgeStr(const std::string& val);
    bool addOpId(char *key,  oboe_metadata_t *md);

    bool addHostname();

    /**
     * Get a new copy of this metadata.
     *
     * NOTE: The returned object must be "delete"d.
     */
    Metadata* getMetadata();
    std::string metadataString();

    void storeOpID(uint8_t *id);

    /**
     * Report this event.
     *
     * This sends the event using the default reporter.
     *
     * @return True on success; otherwise an error message is logged.
     */
    bool send();

    bool send_profiling();

    bool addSpanRef(oboe_metadata_t *md);
    bool addProfileEdge(uint8_t *id);

    static Event* startTrace(const oboe_metadata_t *md);
};


class Span {
public:
    static std::string createSpan(const char *transaction, const char *domain, const int64_t duration, const char *service_name = NULL);

    static std::string createHttpSpan(const char *transaction, const char *url, const char *domain, const int64_t duration,
            const int status, const char *method, const int has_error, const char *service_name = NULL);
};


class MetricTags {
    friend class CustomMetrics;
public:
    MetricTags(size_t count);
    ~MetricTags();
    bool add(size_t index, char *k, char *v);
private:
    oboe_metric_tag_t* get() const;
    oboe_metric_tag_t *tags;
    size_t size;
};

class CustomMetrics {
public:
    static int summary(const char *name, const double value, const int count, const int host_tag,
            const char *service_name, const MetricTags *tags, size_t tags_count);

    static int increment(const char *name, const int count, const int host_tag,
            const char *service_name, const MetricTags *tags, size_t tags_count);
};

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
        std::string hostname_alias,  // optional hostname alias
        int log_level,               // level at which log messages will be written to log file (0-6)
        std::string log_file_path,   // file name including path for log file

        int max_transactions,         // maximum number of transaction names to track
        int max_flush_wait_time,      // maximum wait time for flushing data before terminating in milli seconds
        int events_flush_interval,    // events flush timeout in seconds (threshold for batching messages before sending off)
        int max_request_size_bytes,  // events flush batch size in KB (threshold for batching messages before sending off)

        std::string reporter,      // the reporter to be used ("ssl", "upd", "file", "null")
        std::string host,          // collector endpoint (reporter=ssl), udp address (reporter=udp), or file path (reporter=file)
        std::string service_key,   // the service key (also known as access_key)
        std::string trusted_path,  // path to the SSL certificate (only for ssl)

        int buffer_size,            // size of the message buffer
        int trace_metrics,          // flag indicating if trace metrics reporting should be enabled (default) or disabled
        int histogram_precision,    // the histogram precision (only for ssl)
        int token_bucket_capacity,  // custom token bucket capacity
        int token_bucket_rate,      // custom token bucket rate
        int file_single,            // use single files in file reporter for each event

        int ec2_metadata_timeout  // the timeout (milli seconds) for retrieving EC2 metadata
    );

    ~Reporter();

    bool sendReport(Event *evt);
    bool sendReport(Event *evt, oboe_metadata_t *md);
    bool sendStatus(Event *evt) ;
    bool sendStatus(Event *evt, oboe_metadata_t *md) ;
    bool sendProfile(Event *evt, oboe_metadata_t *md);
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
extern "C" void oboe_debug_log_handler(void *context, int module, int level,
                                       const char *source_name, int source_lineno,
                                       const char *msg);

class DebugLog {
public:
    /**
     * Get a printable name for a diagnostics logging level.
     *
     * @param level A detail level in the range 0 to 6 (OBOE_DEBUG_FATAL to OBOE_DEBUG_HIGH).
     */
    static std::string getLevelName(int level);
    /**
     * Get a printable name for a diagnostics logging module identifier.
     *
     * @param module One of the OBOE_MODULE_* values.
     */
    static std::string getModuleName(int module);

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
    static int getLevel(int module);

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
    static void setLevel(int module, int newLevel);
    /**
     * Set the output stream for the default logger.
     *
     * @param newStream A valid, open FILE* stream or NULL to disable the default logger.
     * @return Zero on success; otherwise an error code (normally from errno).
     */
    static int setOutputStream(FILE *newStream) ;

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
    static int setOutputFile(const char *pathname);

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
    static int addDebugLogger(DebugLogger *newLogger, int logLevel);

    /**
     * Remove a logger.
     *
     * Remove the logger from the message handling chain.
     *
     * @return Zero on success, one if it was not found, and otherwise a negative
     *          value to indicate an error.
     */
    static int removeDebugLogger(DebugLogger *oldLogger);

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
    static void logMessage(int module, int level, const char *source_name,
    int source_lineno, const char *msg);
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
    static bool checkVersion(int version, int revision);

    /**
     * Get the Oboe library version number.
     *
     * This number increments whenever an incompatible change to the API/ABI is made.
     *
     * @return The library's version number or -1 if the version is not known.
     */
    static int getVersion();

    /**
     * Get the Oboe library revision number.
     *
     * This number increments whenever a compatible change is made to the
     * API/ABI (ie. an addition).
     *
     * @return The library's revision number or -1 if not known.
     */
    static int getRevision();
};

#endif      // OBOE_HPP
