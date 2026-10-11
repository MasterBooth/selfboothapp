#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif

/*=============================================================================
 * CommandQueue.h - Thread-safe command queue for serializing SDK operations
 *
 * Purpose: Prevent concurrent EDSDK calls by queuing all operations and
 *          executing them serially on a dedicated executor thread.
 *
 * Design:
 *   - Commands enqueued by any thread (UI, LiveView, callback)
 *   - Single executor thread processes commands sequentially
 *   - Inter-command delays enforce camera firmware requirements
 *   - Priority-based queuing (critical ops before status updates)
 *   - Timing diagnostics for debugging Device Busy issues
 *
 * Usage:
 *   CommandQueue q;
 *   q.enqueue(CommandType::SetProperty, Priority::NORMAL,
 *             [](){ EdsSetPropertyData(...); });
 *   q.wait();  // Wait for execution
 *
 *============================================================================*/

#include "ErrorHandler.h"
#include <queue>
#include <functional>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <vector>
#include <atomic>
#include <memory>

namespace CameraApp {

enum class CommandPriority {
    CRITICAL = 0,  // Capture, AF (user-initiated, blocking)
    HIGH = 1,      // Focus drive, zoom
    NORMAL = 2,    // Property changes
    LOW = 3        // Polling, status updates, boot
};

enum class CommandType {
    // Camera operations
    PropertyGet,
    PropertySet,
    GetDescriptor,
    SendCommand,
    SendStatusCommand,

    // LiveView
    EVFDownload,
    EVFStart,
    EVFStop,

    // Capture
    Capture,
    FileDownload,

    // Initialization
    UILock,
    UIUnlock,
    SetCapacity,
    SetSaveTarget,

    // Custom
    Custom
};

// Forward declaration
class ErrorHandler;

struct Command {
    CommandType type;
    CommandPriority priority;
    std::string description;
    std::function<EdsError()> operation;
    std::function<void(EdsError)> callback;

    // Timing
    std::chrono::high_resolution_clock::time_point enqueueTime;
    std::chrono::high_resolution_clock::time_point startTime;
    std::chrono::high_resolution_clock::time_point endTime;

    // Retry
    int attemptCount = 0;
    EdsError lastError = EDS_ERR_OK;

    Command() = default;

    Command(CommandType t, CommandPriority p, const std::string& desc,
            std::function<EdsError()> op)
        : type(t), priority(p), description(desc), operation(op),
          enqueueTime(std::chrono::high_resolution_clock::now()) {}

    // For priority queue comparison (higher priority first)
    bool operator<(const Command& other) const {
        if (priority != other.priority) {
            return priority > other.priority;  // Lower priority value = higher priority
        }
        // Same priority: FIFO (earlier enqueue time first)
        return enqueueTime > other.enqueueTime;
    }

    int queueWaitMs() const {
        if (startTime.time_since_epoch().count() == 0) return -1;
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            startTime - enqueueTime);
        return (int)ms.count();
    }

    int executionTimeMs() const {
        if (endTime.time_since_epoch().count() == 0) return -1;
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            endTime - startTime);
        return (int)ms.count();
    }

    int totalTimeMs() const {
        if (endTime.time_since_epoch().count() == 0) return -1;
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            endTime - enqueueTime);
        return (int)ms.count();
    }

    std::string statusString() const {
        std::string s = "[" + description + "]";
        s += " priority=" + std::to_string((int)priority);
        s += " attempt=" + std::to_string(attemptCount);
        if (queueWaitMs() >= 0) {
            s += " queue_wait=" + std::to_string(queueWaitMs()) + "ms";
        }
        if (executionTimeMs() >= 0) {
            s += " exec_time=" + std::to_string(executionTimeMs()) + "ms";
        }
        return s;
    }
};

// Comparator for priority queue
struct CommandComparator {
    bool operator()(const std::shared_ptr<Command>& a,
                    const std::shared_ptr<Command>& b) const {
        if (!a || !b) return false;
        return *a < *b;
    }
};

class CommandQueue {
public:
    CommandQueue() : m_running(false), m_totalEnqueued(0) {}

    ~CommandQueue() {
        stop();
    }

    // Start the executor thread
    void start() {
        if (m_running.load()) return;
        m_running.store(true);
        m_executorThread = std::thread([this]() { executorLoop(); });
    }

    // Stop the executor thread and wait for queue to drain
    void stop() {
        m_running.store(false);
        m_cv.notify_one();
        if (m_executorThread.joinable()) {
            m_executorThread.join();
        }
    }

    // Enqueue a command (returns sequence number)
    uint64_t enqueue(CommandType type, CommandPriority priority,
                     const std::string& description,
                     std::function<EdsError()> operation,
                     std::function<void(EdsError)> callback = nullptr) {
        auto cmd = std::make_shared<Command>(type, priority, description, operation);
        cmd->callback = callback;

        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_commands.push(cmd);
            m_totalEnqueued++;
        }

        m_cv.notify_one();
        return m_totalEnqueued - 1;
    }

    // Wait for all commands to complete
    void waitAll() {
        std::unique_lock<std::mutex> lock(m_mutex);
        m_drainCV.wait(lock, [this]() { return m_commands.empty(); });
    }

    // Wait for specific command to complete (by sequence number)
    bool waitFor(uint64_t sequenceNumber, int timeoutMs = 30000) {
        auto deadline = std::chrono::high_resolution_clock::now() +
                        std::chrono::milliseconds(timeoutMs);

        std::unique_lock<std::mutex> lock(m_mutex);
        while (m_totalEnqueued <= sequenceNumber) {
            auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
                deadline - std::chrono::high_resolution_clock::now());
            if (remaining.count() <= 0) return false;
            m_drainCV.wait_for(lock, remaining);
        }
        return true;
    }

    // Get current queue depth
    size_t depth() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_commands.size();
    }

    // Get statistics
    struct Stats {
        uint64_t totalEnqueued = 0;
        uint64_t totalExecuted = 0;
        uint64_t totalFailed = 0;
        uint64_t totalRetried = 0;
        int maxQueueDepth = 0;
        int avgQueueWaitMs = 0;
        int avgExecTimeMs = 0;
    };

    Stats getStats() const {
        std::lock_guard<std::mutex> lock(m_statsMutex);
        return m_stats;
    }

private:
    std::priority_queue<std::shared_ptr<Command>,
                        std::vector<std::shared_ptr<Command>>,
                        CommandComparator>
        m_commands;

    std::thread m_executorThread;
    std::atomic<bool> m_running;
    mutable std::mutex m_mutex;
    std::condition_variable m_cv;
    std::condition_variable m_drainCV;

    uint64_t m_totalEnqueued;
    std::chrono::high_resolution_clock::time_point m_lastCommandTime;

    mutable std::mutex m_statsMutex;
    Stats m_stats;

    // Executor thread main loop
    void executorLoop() {
        while (m_running.load()) {
            std::shared_ptr<Command> cmd;

            {
                std::unique_lock<std::mutex> lock(m_mutex);

                // Wait for command or shutdown signal
                if (!m_cv.wait_for(lock, std::chrono::milliseconds(100),
                                   [this]() { return !m_commands.empty() || !m_running.load(); })) {
                    continue;
                }

                if (!m_running.load()) break;
                if (m_commands.empty()) continue;

                cmd = m_commands.top();
                m_commands.pop();
            }

            if (!cmd) continue;

            // Execute command with inter-command delay
            executeCommand(cmd);

            // Notify waiters that queue may be drained
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                if (m_commands.empty()) {
                    m_drainCV.notify_all();
                }
            }
        }
    }

    void executeCommand(std::shared_ptr<Command> cmd) {
        // Property set/get and capture commands need a small inter-command delay to
        // satisfy Canon camera firmware timing requirements. EVFDownload (live view
        // frame streaming) must NOT be throttled — it runs at 30fps and any artificial
        // delay directly reduces the achievable frame rate.
        const int INTER_COMMAND_DELAY_MS = 50;   // For property ops and capture
        const int EVF_INTER_COMMAND_DELAY_MS = 0; // No delay for live view streaming
        const int RETRY_INITIAL_DELAY_MS = 200;
        const int RETRY_MAX_DELAY_MS = 2000;
        const double RETRY_BACKOFF = 1.5;
        const int MAX_RETRIES = 3;

        const int interDelayMs = (cmd->type == CommandType::EVFDownload)
                                 ? EVF_INTER_COMMAND_DELAY_MS
                                 : INTER_COMMAND_DELAY_MS;

        // Enforce inter-command delay
        auto now = std::chrono::high_resolution_clock::now();
        if (interDelayMs > 0 && m_lastCommandTime.time_since_epoch().count() > 0) {
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
                now - m_lastCommandTime);
            if (elapsed.count() < interDelayMs) {
                std::this_thread::sleep_for(
                    std::chrono::milliseconds(interDelayMs - elapsed.count()));
            }
        }

        cmd->startTime = std::chrono::high_resolution_clock::now();

        // Execute with retry logic. Live-view frame downloads are sampled data:
        // if the camera says the next EVF image is not ready yet, drop this
        // frame and let the stream loop request the next one immediately.
        int retryDelay = RETRY_INITIAL_DELAY_MS;
        const int maxRetries = (cmd->type == CommandType::EVFDownload) ? 0 : MAX_RETRIES;
        for (int attempt = 0; attempt <= maxRetries; ++attempt) {
            cmd->attemptCount = attempt + 1;
            cmd->lastError = cmd->operation();

            if (cmd->lastError == EDS_ERR_OK) {
                break;  // Success
            }

            // Check if error is retryable
            if (cmd->lastError != EDS_ERR_DEVICE_BUSY &&
                cmd->lastError != EDS_ERR_OBJECT_NOTREADY) {
                break;  // Non-retryable error
            }

            // Check retry limit
            if (attempt >= maxRetries) {
                break;  // Out of retries
            }

            // Adjust retry delay based on priority
            if (cmd->priority == CommandPriority::CRITICAL) {
                retryDelay = RETRY_INITIAL_DELAY_MS;
            } else if (cmd->priority == CommandPriority::LOW) {
                retryDelay = RETRY_MAX_DELAY_MS;  // Give up faster for low priority
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(retryDelay));
            retryDelay = (int)(retryDelay * RETRY_BACKOFF);
            if (retryDelay > RETRY_MAX_DELAY_MS) retryDelay = RETRY_MAX_DELAY_MS;
        }

        cmd->endTime = std::chrono::high_resolution_clock::now();
        m_lastCommandTime = cmd->endTime;

        // Log execution
        logCommandExecution(cmd);

        // Invoke callback
        if (cmd->callback) {
            cmd->callback(cmd->lastError);
        }

        // Update statistics
        updateStats(cmd);
    }

    void logCommandExecution(std::shared_ptr<Command> cmd) {
        std::string status = cmd->statusString();

        if (cmd->lastError == EDS_ERR_OK) {
            ErrorHandler::dbg("[CommandQueue::exec]", status + " => OK");
        } else {
            char hexBuf[16];
            snprintf(hexBuf, sizeof(hexBuf), "%08X", cmd->lastError);
            ErrorHandler::log(LogLevel::Warning,
                              "[CommandQueue::exec] " + status + " => ERROR 0x" + std::string(hexBuf));
        }
    }

    void updateStats(std::shared_ptr<Command> cmd) {
        std::lock_guard<std::mutex> lock(m_statsMutex);

        m_stats.totalExecuted++;
        if (cmd->lastError != EDS_ERR_OK) {
            m_stats.totalFailed++;
        }
        if (cmd->attemptCount > 1) {
            m_stats.totalRetried++;
        }

        int queueWait = cmd->queueWaitMs();
        int execTime = cmd->executionTimeMs();

        if (queueWait >= 0) {
            m_stats.avgQueueWaitMs =
                (m_stats.avgQueueWaitMs * (m_stats.totalExecuted - 1) + queueWait) /
                m_stats.totalExecuted;
        }

        if (execTime >= 0) {
            m_stats.avgExecTimeMs =
                (m_stats.avgExecTimeMs * (m_stats.totalExecuted - 1) + execTime) /
                m_stats.totalExecuted;
        }
    }
};

}  // namespace CameraApp
