// Logger.h  -- thread-safe timestamped logger with console + optional file sink.
//
// One global instance (Logger::instance()). Every line goes to stdout and, if a
// file sink was opened via setLogFile(), is mirrored there with the same format.
// A minimum level filter lets production builds drop TRACE/INFO noise.
#pragma once
#include <mutex>
#include <string>
#include <cstdio>

enum class LogLevel { Trace, Info, Warn, Error };

class Logger {
public:
    static Logger& instance();
    ~Logger();

    // Mirror output to `path` (appended). Returns false if the file can't open;
    // console logging continues regardless.
    bool setLogFile(const std::string& path);

    // Drop any message below `lvl`. Default: Trace (log everything).
    void setMinLevel(LogLevel lvl) { m_minLevel = lvl; }

    void log(LogLevel lvl, const std::string& tag, const std::string& msg);

    // printf-style convenience wrappers.
    void info (const char* tag, const char* fmt, ...);
    void warn (const char* tag, const char* fmt, ...);
    void error(const char* tag, const char* fmt, ...);
    void trace(const char* tag, const char* fmt, ...);

private:
    Logger() = default;
    std::mutex m_mtx;
    std::FILE* m_file     = nullptr;
    LogLevel   m_minLevel = LogLevel::Trace;
    static const char* levelName(LogLevel l);
};
