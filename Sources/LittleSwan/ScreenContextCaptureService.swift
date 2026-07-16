import AppKit
import CoreGraphics
import Foundation
import LittleSwanCore
import ScreenCaptureKit
import Vision

struct ExternalWindowTarget: Equatable, Sendable {
    var windowID: CGWindowID?
    var ownerProcessID: pid_t
    var appName: String
    var bundleIdentifier: String?
    var windowTitle: String?
}

@MainActor
final class ExternalWindowTracker: NSObject {
    private(set) var target: ExternalWindowTarget?

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
        rememberIfExternal(application)
    }

    /// Refreshing from window Z-order also covers the first Polish after launch,
    /// before macOS has delivered an external application activation notification.
    func currentTarget() -> ExternalWindowTarget? {
        if let frontExternalWindow = Self.frontExternalWindow() {
            target = frontExternalWindow
        }
        return target
    }

    private func rememberIfExternal(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              application.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        let window = Self.frontWindow(for: application.processIdentifier)
        target = ExternalWindowTarget(
            windowID: window?.id,
            ownerProcessID: application.processIdentifier,
            appName: application.localizedName ?? "Other app",
            bundleIdentifier: application.bundleIdentifier,
            windowTitle: window?.title
        )
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
                ownerProcessID: processID,
                appName: application?.localizedName
                    ?? (window[kCGWindowOwnerName as String] as? String)
                    ?? "Other app",
                bundleIdentifier: application?.bundleIdentifier,
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
        if let windowID = target.windowID,
           let exactMatch = windows.first(where: { $0.windowID == windowID }) {
            return exactMatch
        }

        return windows
            .filter { window in
                window.owningApplication?.processID == target.ownerProcessID
                    && window.windowLayer == 0
                    && window.frame.width >= 240
                    && window.frame.height >= 160
            }
            .max { left, right in
                left.frame.width * left.frame.height < right.frame.width * right.frame.height
            }
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
