import AppKit
import ApplicationServices
import Foundation

actor AppleMusicAccessibilityQualityProvider: AudioQualityProvider {
    nonisolated let identifier = "apple-music-accessibility"
    private var createdBackgroundWindow = false

    func currentQuality(for mediaInfo: MediaInfo) async -> AudioQualityProviderResult {
        guard mediaInfo.application == .appleMusic else {
            return .unavailable(.unsupportedSource)
        }
        guard mediaInfo.playbackState == .playing else {
            return .unavailable(.noCurrentMedia)
        }
        guard AXIsProcessTrusted() else {
            return .unavailable(.accessibilityPermissionRequired)
        }
        guard let processIdentifier = await MainActor.run(body: {
            Self.musicProcessIdentifier()
        }) else {
            return .unavailable(.providerUnavailable)
        }

        let providerIdentifier = identifier
        let initialResult = await Task.detached(priority: .utility) {
            Self.scanMusicPlaybackControls(
                processIdentifier: processIdentifier,
                providerIdentifier: providerIdentifier
            )
        }.value
        let canRecoverByCreatingPlaybackWindow = initialResult == .unavailable(.providerUnavailable)
            || initialResult == .unavailable(.noPlaybackEvidence)
        guard canRecoverByCreatingPlaybackWindow,
              await AppleMusicQualityWindowKeeper.createWindowIfMissing() else {
            return initialResult
        }
        createdBackgroundWindow = true

        try? await Task.sleep(for: .milliseconds(150))
        return await Task.detached(priority: .utility) {
            Self.scanMusicPlaybackControls(
                processIdentifier: processIdentifier,
                providerIdentifier: providerIdentifier
            )
        }.value
    }

    func stopMonitoring() async {
        guard createdBackgroundWindow else { return }
        await AppleMusicQualityWindowKeeper.closeMinimizedWindow()
        createdBackgroundWindow = false
    }

    @MainActor
    private static func musicProcessIdentifier() -> pid_t? {
        NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.Music"
        ).first?.processIdentifier
    }

    nonisolated private static func scanMusicPlaybackControls(
        processIdentifier: pid_t,
        providerIdentifier: String
    ) -> AudioQualityProviderResult {
        let application = AXUIElementCreateApplication(processIdentifier)
        guard let windows = arrayAttribute(kAXWindowsAttribute as CFString, of: application),
              !windows.isEmpty else {
            return .unavailable(.providerUnavailable)
        }

        let playbackWindows = windows.filter {
            booleanAttribute(kAXMainAttribute as CFString, of: $0) == true
                || booleanAttribute(kAXMinimizedAttribute as CFString, of: $0) == true
        }
        guard !playbackWindows.isEmpty else {
            return .unavailable(.providerUnavailable)
        }

        for window in playbackWindows.prefix(2) {
            guard let windowFrame = frame(of: window) else { continue }
            let playbackRegion = CGRect(
                x: windowFrame.minX,
                y: windowFrame.minY,
                width: windowFrame.width,
                height: min(120, windowFrame.height)
            )
            let evidence = evidenceStrings(
                in: window,
                constrainedTo: playbackRegion,
                maximumDepth: 12,
                maximumElements: 500
            )
            if let quality = parseQuality(
                from: evidence,
                providerIdentifier: providerIdentifier
            ) {
                return .verified(quality)
            }
        }

        return .unavailable(.noPlaybackEvidence)
    }

    nonisolated private static func evidenceStrings(
        in root: AXUIElement,
        constrainedTo region: CGRect,
        maximumDepth: Int,
        maximumElements: Int
    ) -> [String] {
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var cursor = 0
        var strings: [String] = []

        while cursor < queue.count, cursor < maximumElements {
            let (element, depth) = queue[cursor]
            cursor += 1

            if depth > 0, let elementFrame = frame(of: element), !elementFrame.intersects(region) {
                continue
            }

            let role = stringAttribute(kAXRoleAttribute as CFString, of: element)
            if role == (kAXButtonRole as String) {
                for attribute in [
                    kAXTitleAttribute,
                    kAXDescriptionAttribute,
                    kAXHelpAttribute,
                    kAXValueAttribute,
                    kAXIdentifierAttribute
                ] {
                    if let string = stringAttribute(attribute as CFString, of: element),
                       !string.isEmpty {
                        strings.append(string)
                    }
                }
            }

            guard depth < maximumDepth,
                  let children = arrayAttribute(kAXChildrenAttribute as CFString, of: element) else {
                continue
            }
            queue.append(contentsOf: children.map { ($0, depth + 1) })
        }

        return strings
    }

    nonisolated static func parseQuality(
        from evidence: [String],
        providerIdentifier: String
    ) -> VerifiedAudioQuality? {
        let joined = evidence.joined(separator: " | ")
        let normalized = joined.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        ).lowercased()

        let hiResTerms = [
            "hi-res lossless", "hi res lossless", "high resolution lossless",
            "高解析无损", "高解析度无损", "高分辨率无损"
        ]
        let losslessTerms = ["lossless", "无损", "無損"]

        let tier: AudioQualityTier
        if hiResTerms.contains(where: normalized.contains) {
            tier = .hiResLossless
        } else if losslessTerms.contains(where: normalized.contains) {
            tier = .lossless
        } else {
            return nil
        }

        return VerifiedAudioQuality(
            tier: tier,
            sampleRate: firstInteger(
                in: joined,
                patterns: [#"(?i)(\d{2,3}(?:[.,]\d+)?)\s*kHz"#],
                multiplier: 1_000
            ),
            bitDepth: firstInteger(
                in: joined,
                patterns: [#"(?i)(\d{1,2})\s*[- ]?bit"#, #"(\d{1,2})\s*位"#]
            ),
            bitRate: firstInteger(
                in: joined,
                patterns: [#"(?i)(\d{2,4})\s*kbps"#]
            ),
            evidenceDescription: tier.displayName,
            providerIdentifier: providerIdentifier
        )
    }

    nonisolated private static func firstInteger(
        in text: String,
        patterns: [String],
        multiplier: Double = 1
    ) -> Int? {
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  let match = expression.firstMatch(
                    in: text,
                    range: NSRange(text.startIndex..., in: text)
                  ),
                  let range = Range(match.range(at: 1), in: text) else {
                continue
            }
            let value = String(text[range]).replacingOccurrences(of: ",", with: ".")
            if let number = Double(value) {
                return Int((number * multiplier).rounded())
            }
        }
        return nil
    }

    nonisolated private static func stringAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }

    nonisolated private static func arrayAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let values = value as? [AnyObject] else {
            return nil
        }
        return values.compactMap { item in
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else { return nil }
            return (item as! AXUIElement)
        }
    }

    nonisolated private static func booleanAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let number = value as? NSNumber else {
            return nil
        }
        return number.boolValue
    }

    nonisolated private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &sizeValue
        ) == .success,
        let positionValue,
        let sizeValue,
        CFGetTypeID(positionValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }
}

private enum AppleMusicQualityWindowKeeper {
    static func createWindowIfMissing() async -> Bool {
        guard let scriptURL = Bundle.main.url(
            forResource: "EnsureMusicQualityWindow",
            withExtension: "applescript",
            subdirectory: "Scripts"
        ) else {
            return false
        }

        return await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [scriptURL.path]
            process.standardOutput = output
            process.standardError = errors

            do {
                try process.run()
            } catch {
                return false
            }

            let outputData = output.fileHandleForReading.readDataToEndOfFile()
            _ = errors.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let result = String(data: outputData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            return result == "created"
        }.value
    }

    static func closeMinimizedWindow() async {
        guard let scriptURL = Bundle.main.url(
            forResource: "CloseMusicQualityWindow",
            withExtension: "applescript",
            subdirectory: "Scripts"
        ) else {
            return
        }
        _ = await run(scriptURL: scriptURL)
    }

    private static func run(scriptURL: URL) async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [scriptURL.path]
            process.standardOutput = output
            process.standardError = Pipe()
            do {
                try process.run()
            } catch {
                return nil
            }
            let outputData = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
}
