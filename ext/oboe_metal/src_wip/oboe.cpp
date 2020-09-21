/**
 * @file oboe.cxx - C++ liboboe wrapper primarily for generating SWIG interfaces
 *
 * This API should follow https://github.com/tracelytics/tracelons/wiki/Instrumentation-API
 **/

#include "oboe.hpp"

/////// Metatdata ///////
Metadata::Metadata(oboe_metadata_t *md) {
    oboe_metadata_copy(this, md);
}

Metadata::~Metadata() {
    oboe_metadata_destroy(this);
}

Metadata *Metadata::makeRandom(bool sampled) {
    oboe_metadata_t md;
    oboe_metadata_init(&md);
    oboe_metadata_random(&md);

    if (sampled) md.flags |= XTR_FLAGS_SAMPLED;

    return new Metadata(&md);  // copies md
}

Metadata *Metadata::copy() {
    return new Metadata(this);
}

bool Metadata::isValid() {
    return oboe_metadata_is_valid(this);
}

bool Metadata::isSampled() {
    return oboe_metadata_is_sampled(this);
}

Metadata *Metadata::fromString(std::string s) {
    oboe_metadata_t md;
    oboe_metadata_fromstr(&md, s.data(), s.size());
    return new Metadata(&md);  // copies md
}

oboe_metadata_t *Metadata::metadata() {
    return this;
}

Event *Metadata::createEvent() {
    return new Event(this);
}

#ifdef SWIGJAVA
std::string Metadata::toStr() {
#else
std::string Metadata::toString() {
#endif
    char buf[OBOE_MAX_METADATA_PACK_LEN];  // Flawfinder: ignore

    int rc = oboe_metadata_tostr(this, buf, sizeof(buf) - 1);
    if (rc == 0) {
        return std::string(buf);
    } else {
        return std::string();  // throw exception?
    }
}

/////// Context ///////

void Context::setTracingMode(int newMode) {
    oboe_settings_mode_set(newMode);
}

void Context::setDefaultSampleRate(int newRate) {
    oboe_settings_rate_set(newRate);
}

void Context::getDecisions(
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
    const char *in_xtrace,
    int custom_tracing_mode,
    int custom_sample_rate,
    int request_type,
    int custom_trigger_mode,
    const char *header_options,
    const char *header_signature,
    long header_timestamp) {
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

oboe_metadata_t *Context::get() {
    return oboe_context_get();
}

#ifdef SWIGJAVA
std::string Context::toStr() {
#else
std::string Context::toString() {
#endif
    char buf[OBOE_MAX_METADATA_PACK_LEN];  // Flawfinder: ignore

    oboe_metadata_t *md = Context::get();
    int rc = oboe_metadata_tostr(md, buf, sizeof(buf) - 1);
    if (rc == 0) {
        return std::string(buf);
    } else {
        return std::string();  // throw exception?
    }
}

void Context::set(oboe_metadata_t *md) {
    oboe_context_set(md);
}

void Context::fromString(std::string s) {
    oboe_context_set_fromstr(s.data(), s.size());
}

// this new object is managed by SWIG %newobject
Metadata *Context::copy() {
    return new Metadata(Context::get());
}

void Context::setSampledFlag() {
    oboe_metadata_t *md = Context::get();
    md->flags |= XTR_FLAGS_SAMPLED;
}

void Context::clear() {
    oboe_context_clear();
}

bool Context::isValid() {
    return oboe_context_is_valid();
}

bool Context::isSampled() {
    return oboe_context_is_sampled();
}

std::string Context::validateTransformServiceName(std::string service_key) {
    char service_key_cpy[71 + 1 + 256];  // Flawfinder: ignore, key=71, colon=1, name<=255
    memset(service_key_cpy, 0, sizeof(service_key_cpy));
    strncpy(service_key_cpy, service_key.c_str(), sizeof(service_key_cpy) - 1);  // Flawfinder: ignore
    int len = strlen(service_key_cpy);                                           // Flawfinder: ignore
    int ret = oboe_validate_transform_service_name(service_key_cpy, &len);

    if (ret == -1) {
        return "";
    }

    return std::string(service_key_cpy);
}

void Context::shutdown() {
    oboe_shutdown();
}

int Context::isReady(unsigned int timeout) {
    return oboe_is_ready(timeout);
}

/**
 * Create a new event object with a new trace context.
 *
 * NOTE: The returned object must be "delete"d.
 */
Event *Context::createEvent() {
    return new Event(Context::get());
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

/////// Event ///////
Event::Event() {
    oboe_event_init(this, Context::get(), NULL);
}

Event::Event(const oboe_metadata_t *md, bool addEdge) {
    // both methods copy metadata from md -> this
    if (addEdge) {
        // create_event automatically adds edge in event to md
        oboe_metadata_create_event(md, this);
    } else {
        // initializes new Event with this md's task_id & new random op_id; no edges set
        oboe_event_init(this, md, NULL);
    }
}

Event::~Event() {
    oboe_event_destroy(this);
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

// called e.g. from Python e.addInfo("Key", None) & Ruby e.addInfo("Key", nil)
bool Event::addInfo(char *key, void *val) {
    // oboe_event_add_info(evt, key, NULL) does nothing
    (void)key;
    (void)val;
    return true;
}

bool Event::addInfo(char *key, const std::string &val) {
    if (memchr(val.data(), '\0', val.size())) {
        return oboe_event_add_info_binary(this, key, val.data(), val.size()) == 0;
    } else {
        return oboe_event_add_info(this, key, val.data()) == 0;
    }
}

bool Event::addInfo(char *key, long val) {
    int64_t val_ = val;
    return oboe_event_add_info_int64(this, key, val_) == 0;
}

bool Event::addInfo(char *key, double val) {
    return oboe_event_add_info_double(this, key, val) == 0;
}

bool Event::addInfo(char *key, const long *vals, int num) {
    oboe_bson_append_start_array(&(this->bbuf), key);
    for (int i = 0; i < num; i++) {
        char index[5];            // Flawfinder: ignore
        sprintf(index, "%d", i);  // Flawfinder: ignore
        oboe_bson_append_long(&(this->bbuf), index, (int64_t)vals[i]);
    }
    oboe_bson_append_finish_object(&(this->bbuf));
    return true;
}

// Ruby
// for profiling to add an array of frames
// called from c++ not Ruby

bool Event::addInfo(char *key, const std::vector<FrameData> &vals) {
    oboe_bson_append_start_array(&(this->bbuf), key);
    int i = 0;
    for (FrameData val : vals) {
        char index[5];            // Flawfinder: ignore
        sprintf(index, "%d", i);  // Flawfinder: ignore
        i++;
        oboe_bson_append_start_object(&(this->bbuf), index);

        if (val.method != "")
            oboe_bson_append_string(&(this->bbuf), "M", (val.method).c_str());
        if (val.klass != "")
            oboe_bson_append_string(&(this->bbuf), "C", (val.klass).c_str());
        if (val.file != "")
            oboe_bson_append_string(&(this->bbuf), "F", (val.file).c_str());
        if (val.lineno != 0)
            oboe_bson_append_long(&(this->bbuf), "L", (int64_t)val.lineno);

        oboe_bson_append_finish_object(&(this->bbuf));
    }
    oboe_bson_append_finish_object(&(this->bbuf));
    return true;
}

bool Event::addEdge(oboe_metadata_t *md) {
    return oboe_event_add_edge(this, md) == 0;
}

bool Event::addEdgeStr(const std::string &val) {
    return oboe_event_add_edge_fromstr(this, val.c_str(), val.size()) == 0;
}

bool Event::addHostname() {
    static char oboe_hostname[HOST_NAME_MAX + 1] = {'\0'};  // Flawfinder: ignore

    if (oboe_hostname[0] == '\0') {
        (void)gethostname(oboe_hostname, sizeof(oboe_hostname) - 1);
        if (oboe_hostname[0] == '\0') {
            // Something is wrong but we don't want to to report this more than
            // once so we'll set it to a minimal non-empty string.
            OBOE_DEBUG_LOG_WARNING(OBOE_MODULE_LIBOBOE, "Failed to get hostname, setting it to '?'");
            oboe_hostname[0] = '?';
            oboe_hostname[1] = '\0';
        }
    }
    return oboe_event_add_info(this, "Hostname", oboe_hostname) == 0;
}

bool Event::addContextOpId(oboe_metadata_t *md) {
    char buf[64]; /* holds btoh'd op_id */ /* Flawfinder: ignore */
    assert(2 * OBOE_MAX_OP_ID_LEN < sizeof(buf));

    memmove(buf, md->ids.op_id, OBOE_MAX_OP_ID_LEN);
    oboe_btoh((uint8_t *)buf, buf, OBOE_MAX_OP_ID_LEN);
    buf[2 * OBOE_MAX_OP_ID_LEN] = '\0';

    return oboe_event_add_info(this, "ContextOpId", buf);
}

bool Event::addSpanRef(oboe_metadata_t *md) {
    char buf[64]; /* holds btoh'd op_id */ /* Flawfinder: ignore */

    assert(2 * OBOE_MAX_OP_ID_LEN < sizeof(buf));

    memmove(buf, md->ids.op_id, OBOE_MAX_OP_ID_LEN);
    oboe_btoh((uint8_t *)buf, buf, OBOE_MAX_OP_ID_LEN);
    buf[2 * OBOE_MAX_OP_ID_LEN] = '\0';

    return oboe_event_add_info(this, "SpanRef", buf);
}

bool Event::addProfileEdge(uint8_t *id) {
    char buf[64]; /* holds btoh'd op_id */ /* Flawfinder: ignore */

    assert(2 * OBOE_MAX_OP_ID_LEN < sizeof(buf));

    memmove(buf, id, OBOE_MAX_OP_ID_LEN);

    oboe_btoh((uint8_t *)buf, buf, OBOE_MAX_OP_ID_LEN);
    buf[2 * OBOE_MAX_OP_ID_LEN] = '\0';

    return oboe_event_add_info(this, "Edge", buf);
}

/**
     * Get a new copy of this metadata.
     *
     * NOTE: The returned object must be "delete"d.
     */
Metadata *Event::getMetadata() {
    return new Metadata(&this->metadata);
}

void Event::extractOpID(uint8_t *id) {
    memmove(id, this->metadata.ids.op_id, OBOE_MAX_OP_ID_LEN);
    return;
}

std::string Event::metadataString() {
    char buf[OBOE_MAX_METADATA_PACK_LEN];  // Flawfinder: ignore

    int rc = oboe_metadata_tostr(&this->metadata, buf, sizeof(buf) - 1);
    if (rc == 0) {
        return std::string(buf);
    } else {
        return std::string();  // throw exception?
    }
}

/**
     * Report this event.
     *
     * This sends the event using the default reporter.
     *
     * @return True on success; otherwise an error message is logged.
     */
bool Event::send() {
    return (oboe_event_send(OBOE_SEND_EVENT, this, Context::get()) >= 0);
}

/**
 * Report a Profiling Event
 * needs to be sent raw, so that the timestamp doesn't get altered
 */
bool Event::sendProfiling() {
    int retval = -1;

    this->bb_str = oboe_bson_buffer_finish(&this->bbuf);
    if (!this->bb_str)
        return -1;

    size_t len = (size_t)(this->bbuf.cur - this->bbuf.buf);
    retval = oboe_raw_send(OBOE_SEND_PROFILING, this->bb_str, len);

    if (retval < 0)
        OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_LIBOBOE, "Raw send failed - reporter returned %d", retval);

    return (retval >= 0);
}

/////// Span ///////
std::string Span::createSpan(const char *transaction, const char *domain, const int64_t duration, const char *service_name) {
    oboe_span_params_t params;
    memset(&params, 0, sizeof(oboe_span_params_t));
    params.version = 1;
    params.transaction = transaction;
    params.domain = domain;
    params.duration = duration;
    params.service = service_name;

    char buffer[OBOE_TRANSACTION_NAME_MAX_LENGTH + 1];  // Flawfinder: ignore
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

    char buffer[OBOE_TRANSACTION_NAME_MAX_LENGTH + 1];  // Flawfinder: ignore
    int len = oboe_http_span(buffer, sizeof(buffer), &params);
    if (len > 0) {
        return std::string(buffer);
    } else {
        return "";
    }
}

/////// MetricTags ///////
MetricTags::MetricTags(size_t count) {
    tags = new oboe_metric_tag_t[count];
    size = count;
}

MetricTags::~MetricTags() {
    delete[] tags;
}
bool MetricTags::add(size_t index, char *k, char *v) {
    if (index < size) {
        tags[index].key = k;
        tags[index].value = v;
        return true;
    }
    return false;
}
oboe_metric_tag_t *MetricTags::get() const {
    return tags;
}

/////// CustomMetrics ///////
int CustomMetrics::summary(const char *name, const double value, const int count, const int host_tag,
                           const char *service_name, const MetricTags *tags, size_t tags_count) {
    if (tags->size < tags_count) {
        tags_count = tags->size;
    }
    return oboe_custom_metric_summary(name, value, count, host_tag, service_name, tags->get(), tags_count);
}

int CustomMetrics::increment(const char *name, const int count, const int host_tag,
                             const char *service_name, const MetricTags *tags, size_t tags_count) {
    if (tags->size < tags_count) {
        tags_count = tags->size;
    }
    return oboe_custom_metric_increment(name, count, host_tag, service_name, tags->get(), tags_count);
}

/////// Reporter ///////
Reporter::Reporter(
    std::string hostname_alias,  // optional hostname alias
    int log_level,               // level at which log messages will be written to log file (0-6)
    std::string log_file_path,   // file name including path for log file

    int max_transactions,        // maximum number of transaction names to track
    int max_flush_wait_time,     // maximum wait time for flushing data before terminating in milli seconds
    int events_flush_interval,   // events flush timeout in seconds (threshold for batching messages before sending off)
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

    int ec2_metadata_timeout,  // the timeout (milli seconds) for retrieving EC2 metadata
    std::string grpc_proxy     // HTTP proxy address and port to be used for the gRPC connection
) {
    oboe_init_options_t options;
    memset(&options, 0, sizeof(options));
    options.version = 9;
    oboe_init_options_set_defaults(&options);

    if (hostname_alias != "") {
        options.hostname_alias = hostname_alias.c_str();
    }
    options.log_level = log_level;
    options.log_file_path = log_file_path.c_str();
    options.max_transactions = max_transactions;
    options.max_flush_wait_time = max_flush_wait_time;
    options.events_flush_interval = events_flush_interval;
    options.max_request_size_bytes = max_request_size_bytes;
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
    if (grpc_proxy != "") {
        options.proxy = grpc_proxy.c_str();
    }
    init_status = oboe_init(&options);
}

Reporter::~Reporter() {
    oboe_reporter_destroy(this);
}

bool Reporter::sendReport(Event *evt) {
    return oboe_event_send(OBOE_SEND_EVENT, evt, Context::get()) >= 0;
}

bool Reporter::sendReport(Event *evt, oboe_metadata_t *md) {
    return oboe_event_send(OBOE_SEND_EVENT, evt, md) >= 0;
}

bool Reporter::sendStatus(Event *evt) {
    return oboe_event_send(OBOE_SEND_STATUS, evt, Context::get()) >= 0;
}

bool Reporter::sendStatus(Event *evt, oboe_metadata_t *md) {
    return oboe_event_send(OBOE_SEND_STATUS, evt, md) >= 0;
}

bool Config::checkVersion(int version, int revision) {
    return (oboe_config_check_version(version, revision) != 0);
}

int Config::getVersion() {
    return oboe_config_get_version();
}

int Config::getRevision() {
    return oboe_config_get_revision();
}

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

    /**
     * Get a printable name for a diagnostics logging level.
     *
     * @param level A detail level in the range 0 to 6 (OBOE_DEBUG_FATAL to OBOE_DEBUG_HIGH).
     */
    std::string DebugLog::getLevelName(int level) {
        return std::string(oboe_debug_log_level_name(level));
    }

    /**
     * Get a printable name for a diagnostics logging module identifier.
     *
     * @param module One of the OBOE_MODULE_* values.
     */
    std::string DebugLog::getModuleName(int module) {
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
    int DebugLog::getLevel(int module) {
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
    void DebugLog::setLevel(int module, int newLevel) {
        oboe_debug_log_level_set(module, newLevel);
    }

    /**
     * Set the output stream for the default logger.
     *
     * @param newStream A valid, open FILE* stream or NULL to disable the default logger.
     * @return Zero on success; otherwise an error code (normally from errno).
     */
    int DebugLog::setOutputStream(FILE *newStream) {
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
    int DebugLog::setOutputFile(const char *pathname) {
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
    int DebugLog::addDebugLogger(DebugLogger *newLogger, int logLevel) {
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
    int DebugLog::removeDebugLogger(DebugLogger *oldLogger) {
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
    void DebugLog::logMessage(int module, int level, const char *source_name, int source_lineno, const char *msg) {
        oboe_debug_logger(module, level, source_name, source_lineno, "%s", msg);
    }
