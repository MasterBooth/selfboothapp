#include "Logger.h"
#include <chrono>
#include <cstdarg>
#include <ctime>

Logger& Logger::instance() {
    static Logger g;
    return g;
}

Logger::~Logger() {
    if (m_file) {
        std::fclose(m_file);
        m_file = nullptr;
    }
}

bool Logger::setLogFile(const std::string& path) {
    std::lock_guard<std::mutex> lk(m_mtx);
    if (m_file) { std::fclose(m_file); m_file = nullptr; }
    // Append so a crashed-then-restarted booth keeps one continuous log.
    errno_t e = ::fopen_s(&m_file, path.c_str(), "ab");
    return e == 0 && m_file != nullptr;
}

const char* Logger::levelName(LogLevel l) {
    switch (l) {
        case LogLevel::Trace: return "TRACE";
        case LogLevel::Info:  return "INFO ";
        case LogLevel::Warn:  return "WARN ";
        case LogLevel::Error: return "ERROR";
    }
    return "?????";
}

void Logger::log(LogLevel lvl, const std::string& tag, const std::string& msg) {
    if (static_cast<int>(lvl) < static_cast<int>(m_minLevel)) return;

    using namespace std::chrono;
    auto now = system_clock::now();
    auto ms  = duration_cast<milliseconds>(now.time_since_epoch()) % 1000;
    std::time_t t = system_clock::to_time_t(now);
    std::tm tm{};
    localtime_s(&tm, &t);
    char ts[32];
    std::snprintf(ts, sizeof(ts), "%02d:%02d:%02d.%03d",
                  tm.tm_hour, tm.tm_min, tm.tm_sec, static_cast<int>(ms.count()));

    std::lock_guard<std::mutex> lk(m_mtx);
    std::printf("[%s] %s [%-10s] %s\n", ts, levelName(lvl), tag.c_str(), msg.c_str());
    std::fflush(stdout);
    if (m_file) {
        // Include the date in the file so a rolling log is self-describing.
        char date[16];
        std::snprintf(date, sizeof(date), "%04d-%02d-%02d",
                      tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
        std::fprintf(m_file, "%s %s %s [%-10s] %s\n",
                     date, ts, levelName(lvl), tag.c_str(), msg.c_str());
        std::fflush(m_file);
    }
}

static std::string vformat(const char* fmt, va_list ap) {
    char buf[1024];
    std::vsnprintf(buf, sizeof(buf), fmt, ap);
    return std::string(buf);
}

#define LOGGER_IMPL(fn, lvl)                              \
void Logger::fn(const char* tag, const char* fmt, ...) { \
    va_list ap; va_start(ap, fmt);                       \
    std::string s = vformat(fmt, ap);                    \
    va_end(ap);                                          \
    log(lvl, tag, s);                                    \
}
LOGGER_IMPL(info,  LogLevel::Info)
LOGGER_IMPL(warn,  LogLevel::Warn)
LOGGER_IMPL(error, LogLevel::Error)
LOGGER_IMPL(trace, LogLevel::Trace)
#undef LOGGER_IMPL
