#pragma once

/*=============================================================================
 * FileDownloader.h - Download files from camera to host PC
 *
 * Layer: Capture
 * Purpose: Handles downloading image files from camera storage to local
 *          filesystem. Supports progress callbacks and proper cleanup.
 *============================================================================*/

#include "../Core/Types.h"
#include "../Core/ErrorHandler.h"
#include "../Event/EventDispatcher.h"

#include <string>
#include <functional>

namespace CameraApp {

class FileDownloader {
public:
    using ProgressCallback = std::function<void(EdsUInt32 percent)>;

    explicit FileDownloader(EventDispatcher& dispatcher)
        : m_dispatcher(dispatcher) {}

    // -----------------------------------------------------------------------
    // Set the local directory to save downloaded files
    // -----------------------------------------------------------------------
    void setSaveDirectory(const std::string& directory) {
        m_saveDirectory = directory;
        // Ensure trailing separator
        if (!m_saveDirectory.empty() &&
            m_saveDirectory.back() != '/' &&
            m_saveDirectory.back() != '\\') {
            m_saveDirectory += '/';
        }
    }

    const std::string& saveDirectory() const { return m_saveDirectory; }

    void setProgressCallback(ProgressCallback cb) {
        m_progressCallback = std::move(cb);
    }

    // -----------------------------------------------------------------------
    // Download a file from camera (called when DirItemRequestTransfer fires)
    // -----------------------------------------------------------------------
    Result download(EdsDirectoryItemRef dirItem, DownloadedFile& outFile) {
        ErrorHandler::log(LogLevel::Info, "========== FileDownloader::download() START ==========");
        ErrorHandler::log(LogLevel::Debug,
            "dirItem=0x" + std::to_string((uintptr_t)dirItem) +
            " saveDir='" + m_saveDirectory + "'");

        // Get file info
        EdsDirectoryItemInfo dirItemInfo;
        EdsError err = EdsGetDirectoryItemInfo(dirItem, &dirItemInfo);
        if (err != EDS_ERR_OK) {
            ErrorHandler::log(LogLevel::Error,
                "EdsGetDirectoryItemInfo FAILED: 0x" + std::to_string(err) + " (" +
                ErrorHandler::errorToString(err) + ")");
            return ErrorHandler::check(err, "EdsGetDirectoryItemInfo");
        }
        ErrorHandler::log(LogLevel::Debug, "EdsGetDirectoryItemInfo OK");

        outFile.fileName = dirItemInfo.szFileName;
        outFile.fileSize = dirItemInfo.size;
        outFile.localPath = m_saveDirectory + outFile.fileName;

        ErrorHandler::log(LogLevel::Info,
            "FILE INFO: name='" + outFile.fileName + "' size=" + std::to_string(outFile.fileSize) +
            " bytes");
        ErrorHandler::log(LogLevel::Debug, "Will save to: '" + outFile.localPath + "'");

        // Notify download start
        DownloadProgressEvent startEvent;
        startEvent.fileName = outFile.fileName;
        startEvent.percent  = 0;
        m_dispatcher.dispatch(startEvent);

        // Create file stream on host
        ErrorHandler::log(LogLevel::Info, "[Download Step 1] Creating file stream...");
        EdsStreamRef stream = nullptr;
        err = EdsCreateFileStream(
            outFile.localPath.c_str(),
            kEdsFileCreateDisposition_CreateAlways,
            kEdsAccess_ReadWrite,
            &stream);
        if (err != EDS_ERR_OK) {
            ErrorHandler::log(LogLevel::Error,
                "EdsCreateFileStream FAILED: 0x" + std::to_string(err) + " (" +
                ErrorHandler::errorToString(err) + ")");
            EdsDownloadCancel(dirItem);
            return ErrorHandler::check(err, "EdsCreateFileStream");
        }
        ErrorHandler::log(LogLevel::Info, "SUCCESS - file stream created");

        // Set progress callback
        if (m_progressCallback) {
            m_currentCallback = m_progressCallback;
            EdsSetProgressCallback(stream, progressFunc, kEdsProgressOption_Periodically, this);
        }

        // Download the file
        ErrorHandler::log(LogLevel::Info,
            "[Download Step 2] Downloading " + std::to_string(dirItemInfo.size) + " bytes...");
        err = EdsDownload(dirItem, dirItemInfo.size, stream);
        if (err != EDS_ERR_OK) {
            ErrorHandler::log(LogLevel::Error,
                "EdsDownload FAILED: 0x" + std::to_string(err) + " (" +
                ErrorHandler::errorToString(err) + ")");
            EdsRelease(stream);
            EdsDownloadCancel(dirItem);
            return ErrorHandler::check(err, "EdsDownload");
        }
        ErrorHandler::log(LogLevel::Info, "SUCCESS - file downloaded to local stream");

        // Signal download complete to camera
        ErrorHandler::log(LogLevel::Info, "[Download Step 3] Signaling download complete to camera...");
        err = EdsDownloadComplete(dirItem);
        if (err != EDS_ERR_OK) {
            ErrorHandler::log(LogLevel::Error,
                "EdsDownloadComplete FAILED: 0x" + std::to_string(err) + " (" +
                ErrorHandler::errorToString(err) + ")");
            EdsRelease(stream);
            return ErrorHandler::check(err, "EdsDownloadComplete");
        }
        ErrorHandler::log(LogLevel::Info, "SUCCESS - camera notified");

        // Release stream
        EdsRelease(stream);

        // Release the directory item reference
        EdsRelease(dirItem);

        outFile.success = true;

        // Notify download complete — use localPath so listeners get the full filesystem path
        DownloadProgressEvent doneEvent;
        doneEvent.fileName  = outFile.localPath;
        doneEvent.percent   = 100;
        doneEvent.completed = true;
        doneEvent.success   = true;
        m_dispatcher.dispatch(doneEvent);

        ErrorHandler::log(LogLevel::Info,
            "========== Download COMPLETE: " + outFile.localPath + " ==========");

        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Download a file to memory (returns raw bytes)
    // -----------------------------------------------------------------------
    Result downloadToMemory(EdsDirectoryItemRef dirItem,
                            std::vector<uint8_t>& outData,
                            std::string& outFileName) {
        EdsDirectoryItemInfo dirItemInfo;
        EdsError err = EdsGetDirectoryItemInfo(dirItem, &dirItemInfo);
        if (err != EDS_ERR_OK) {
            return ErrorHandler::check(err, "EdsGetDirectoryItemInfo");
        }

        outFileName = dirItemInfo.szFileName;

        // Create memory stream
        EdsStreamRef stream = nullptr;
        err = EdsCreateMemoryStream(dirItemInfo.size, &stream);
        if (err != EDS_ERR_OK) {
            EdsDownloadCancel(dirItem);
            return ErrorHandler::check(err, "EdsCreateMemoryStream");
        }

        // Download
        err = EdsDownload(dirItem, dirItemInfo.size, stream);
        if (err != EDS_ERR_OK) {
            EdsRelease(stream);
            EdsDownloadCancel(dirItem);
            return ErrorHandler::check(err, "EdsDownload");
        }

        err = EdsDownloadComplete(dirItem);

        // Copy data from stream
        EdsVoid* dataPtr = nullptr;
        EdsGetPointer(stream, &dataPtr);
        EdsUInt64 length = 0;
        EdsGetLength(stream, &length);

        if (dataPtr && length > 0) {
            outData.resize(static_cast<size_t>(length));
            memcpy(outData.data(), dataPtr, static_cast<size_t>(length));
        }

        EdsRelease(stream);
        EdsRelease(dirItem);

        return ErrorHandler::check(err, "EdsDownloadComplete");
    }

private:
    // Progress callback bridge
    static EdsError EDSCALLBACK progressFunc(
        EdsUInt32 inPercent, EdsVoid* inContext, EdsBool* outCancel)
    {
        auto* self = static_cast<FileDownloader*>(inContext);
        if (self && self->m_currentCallback) {
            self->m_currentCallback(inPercent);
        }
        *outCancel = false;
        return EDS_ERR_OK;
    }

    EventDispatcher&  m_dispatcher;
    std::string       m_saveDirectory = "./image/";
    ProgressCallback  m_progressCallback;
    ProgressCallback  m_currentCallback;  // Active during download
};

} // namespace CameraApp
