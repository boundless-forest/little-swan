import AppKit
import CoreGraphics
import Foundation
import LittleSwanCore
@preconcurrency import ScreenCaptureKit
import Vision

struct ExternalWindowTarget: Equatable, Sendable {
    var windowID: CGWindowID
    var appName: String
    var windowTitle: String?
}

@MainActor
final class ExternalWindowTracker: NSObject {
    private(set) var target: ExternalWindowTarget?
    private var hasPendingPreShowLock = false

    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        rememberIfExternal(NSWorkspace.shared.frontmostApplication)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        if Self.isLittleSwan(application) {
            if hasPendingPreShowLock {
                hasPendingPreShowLock = false
            } else {
                target = Self.frontExternalWindow()
            }
        } else {
            hasPendingPreShowLock = false
            rememberIfExternal(application)
        }
    }

    /// Lock the exact window before Little Swan changes application focus or window order.
    func lockFrontmostExternalWindow() {
        target = Self.frontExternalWindow()
        hasPendingPreShowLock = true
    }

    func currentTarget() -> ExternalWindowTarget? {
        target
    }

    private func rememberIfExternal(_ application: NSRunningApplication?) {
        guard let application,
              !Self.isLittleSwan(application),
              let window = Self.frontWindow(for: application.processIdentifier) else {
            return
        }

        target = ExternalWindowTarget(
            windowID: window.id,
            appName: application.localizedName ?? "Other app",
            windowTitle: window.title
        )
    }

    private static func isLittleSwan(_ application: NSRunningApplication?) -> Bool {
        guard let application else { return false }
        return application.processIdentifier == ProcessInfo.processInfo.processIdentifier
            || application.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private static func frontWindow(for processID: pid_t) -> (id: CGWindowID, title: String?)? {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for window in windowInfo {
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == processID,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let windowNumber = window[kCGWindowNumber as String] as? NSNumber else {
                continue
            }

            let title = window[kCGWindowName as String] as? String
            return (CGWindowID(windowNumber.uint32Value), title)
        }
        return nil
    }

    private static func frontExternalWindow() -> ExternalWindowTarget? {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        for window in windowInfo {
            guard let processNumber = window[kCGWindowOwnerPID as String] as? NSNumber,
                  processNumber.int32Value != currentProcessID,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let windowNumber = window[kCGWindowNumber as String] as? NSNumber,
                  let boundsDictionary = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(
                      dictionaryRepresentation: boundsDictionary as CFDictionary
                  ),
                  bounds.width >= 240,
                  bounds.height >= 160 else {
                continue
            }

            let processID = processNumber.int32Value
            let application = NSRunningApplication(processIdentifier: processID)
            return ExternalWindowTarget(
                windowID: CGWindowID(windowNumber.uint32Value),
                appName: application?.localizedName
                    ?? (window[kCGWindowOwnerName as String] as? String)
                    ?? "Other app",
                windowTitle: window[kCGWindowName as String] as? String
            )
        }
        return nil
    }
}

@MainActor
protocol ScreenContextCapturing: AnyObject {
    func captureContext(for sourceText: String) async throws -> ScreenContext
}

enum ScreenContextCaptureError: LocalizedError, Equatable {
    case permissionRequired
    case noExternalWindow
    case windowUnavailable(String)
    case noRecognizedText(String)
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            "Allow Screen Recording for Little Swan, then relaunch the app."
        case .noExternalWindow:
            "Open the content you are replying to, then return to Little Swan and Polish again."
        case .windowUnavailable(let appName):
            "The previous \(appName) window is no longer available. Open it and Polish again."
        case .noRecognizedText(let appName):
            "No readable text was found in the \(appName) window."
        case .captureFailed(let message):
            "Could not read the previous window: \(message)"
        }
    }

    var requiresScreenRecordingSettings: Bool {
        self == .permissionRequired
    }

    var sourceOnlyFallbackDescription: String {
        switch self {
        case .permissionRequired:
            "Using Source only. Allow Screen Recording to add previous-window context."
        case .noExternalWindow:
            "Using Source only because no previous external window was locked."
        case .windowUnavailable(let appName):
            "Using Source only because the locked \(appName) window is no longer available."
        case .noRecognizedText(let appName):
            "Using Source only because no readable text was found in the locked \(appName) window."
        case .captureFailed:
            "Using Source only because screen context could not be read."
        }
    }
}

@MainActor
final class ScreenContextCaptureService: ScreenContextCapturing {
    private let tracker: ExternalWindowTracker

    init(tracker: ExternalWindowTracker) {
        self.tracker = tracker
    }

    func captureContext(for sourceText: String) async throws -> ScreenContext {
        guard let target = tracker.currentTarget() else {
            throw ScreenContextCaptureError.noExternalWindow
        }

        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenContextCaptureError.permissionRequired
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
            guard let window = matchingWindow(for: target, in: content.windows) else {
                throw ScreenContextCaptureError.windowUnavailable(target.appName)
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            let scale = min(NSScreen.main?.backingScaleFactor ?? 2, 2)
            configuration.width = max(Int(window.frame.width * scale), 1)
            configuration.height = max(Int(window.frame.height * scale), 1)
            configuration.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            let observations = try await Task.detached(priority: .userInitiated) {
                try Self.recognizeText(in: image)
            }.value

            let windowTitle = window.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let context = ScreenContextReducer.makeContext(
                sourceApp: target.appName,
                windowTitle: windowTitle?.isEmpty == false ? windowTitle : target.windowTitle,
                observations: observations,
                sourceText: sourceText
            ) else {
                throw ScreenContextCaptureError.noRecognizedText(target.appName)
            }
            return context
        } catch let error as ScreenContextCaptureError {
            throw error
        } catch {
            throw ScreenContextCaptureError.captureFailed(error.localizedDescription)
        }
    }

    private func matchingWindow(
        for target: ExternalWindowTarget,
        in windows: [SCWindow]
    ) -> SCWindow? {
        // Never silently substitute another window from the same app. If the locked
        // window disappears, Source-only Polish is safer than unrelated OCR context.
        return windows.first(where: { $0.windowID == target.windowID })
    }

    nonisolated private static func recognizeText(
        in image: CGImage
    ) throws -> [ScreenTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return ScreenTextObservation(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }
    }
}
