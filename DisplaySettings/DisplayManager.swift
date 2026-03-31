// DisplayManager.swift
// Discovers connected external displays, reads/writes brightness via DDCHelper.

import Foundation
import AppKit
import CoreGraphics
import IOKit
import IOKit.graphics

@MainActor
final class DisplayManager: ObservableObject {

    @Published var displays: [DisplayModel] = []
    @Published var isRefreshing: Bool = false

    // Debounce: one pending write task per display ID
    private var pendingWrites: [CGDirectDisplayID: DispatchWorkItem] = [:]

    init() {
        Task { await refresh() }
    }

    // MARK: - Refresh

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        displays = await discoverDisplays()
    }

    private func discoverDisplays() async -> [DisplayModel] {
        var models = await Task.detached(priority: .userInitiated) {
            var result: [DisplayModel] = []

            var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
            var displayCount: UInt32 = 0
            CGGetActiveDisplayList(16, &displayIDs, &displayCount)

            for i in 0..<Int(displayCount) {
                let id = displayIDs[i]
                // Skip the built-in Retina display
                if CGDisplayIsBuiltin(id) != 0 { continue }

                let name = DisplayManager.displayName(for: id)
                var model = DisplayModel(id: id, name: name, brightness: 50,
                                        maxBrightness: 100, ddcSupported: true, isLoading: false)

                if let (val, maxVal) = DDCHelper.readBrightness(displayID: id), maxVal > 0 {
                    let pct = Double(val) / Double(maxVal) * 100.0
                    model.brightness = min(max(pct, 0), 100)
                    model.maxBrightness = Double(maxVal)
                    model.ddcSupported = true
                } else {
                    model.ddcSupported = false
                }
                result.append(model)
            }
            return result
        }.value

        // Enrich names with NSScreen.localizedName on the main actor
        DisplayManager.enrichDisplayNames(&models)
        return models
    }

    // MARK: - Brightness write (debounced 300 ms)

    func setBrightness(_ brightness: Double, for displayID: CGDirectDisplayID) {
        // Update the UI value immediately
        if let idx = displays.firstIndex(where: { $0.id == displayID }) {
            displays[idx].brightness = brightness
        }
        // Cancel any pending DDC write for this display
        pendingWrites[displayID]?.cancel()

        let item = DispatchWorkItem {
            let intValue = Int(brightness.rounded())
            DDCHelper.writeBrightness(displayID: displayID, value: intValue)
        }
        pendingWrites[displayID] = item
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    // MARK: - Display name resolution

    /// Safe to call from any thread (no NSScreen access).
    nonisolated static func displayName(for displayID: CGDirectDisplayID) -> String {
        // IOKit name lookup — thread-safe
        if let name = ioKitDisplayName(for: displayID), !name.isEmpty {
            return name
        }
        return "External Display \(displayID)"
    }

    /// Must be called from MainActor for NSScreen access.
    @MainActor
    static func enrichDisplayNames(_ displays: inout [DisplayModel]) {
        for i in displays.indices {
            let id = displays[i].id
            if let screen = NSScreen.screens.first(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id
            }) {
                let localizedName = screen.localizedName
                if !localizedName.isEmpty && displays[i].name.hasPrefix("External Display") {
                    displays[i] = DisplayModel(
                        id: displays[i].id,
                        name: localizedName,
                        brightness: displays[i].brightness,
                        maxBrightness: displays[i].maxBrightness,
                        ddcSupported: displays[i].ddcSupported,
                        isLoading: displays[i].isLoading
                    )
                }
            }
        }
    }

    private nonisolated static func ioKitDisplayName(for displayID: CGDirectDisplayID) -> String? {
        let service = DDCHelper.serviceForDisplay(displayID)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let opts = IOOptionBits(kIODisplayOnlyPreferredName)
        guard let rawInfo = IODisplayCreateInfoDictionary(service, opts) else { return nil }
        let info = rawInfo.takeRetainedValue() as? [String: Any]
        guard let names = info?[kDisplayProductName] as? [String: String],
              let firstName = names.values.first,
              !firstName.isEmpty else { return nil }
        return firstName
    }
}
