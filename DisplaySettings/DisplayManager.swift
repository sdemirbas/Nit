// DisplayManager.swift
// Discovers connected external displays, reads/writes brightness & contrast via DDCHelper.

import Foundation
import AppKit
import CoreGraphics
import IOKit
import IOKit.graphics

@MainActor
final class DisplayManager: ObservableObject {

    @Published var displays: [DisplayModel] = []
    @Published var isRefreshing: Bool = false

    private var pendingWrites:         [CGDirectDisplayID: DispatchWorkItem] = [:]
    private var pendingContrastWrites: [CGDirectDisplayID: DispatchWorkItem] = [:]

    init() {
        Task { await refresh() }
    }

    // MARK: - Computed

    var masterBrightness: Double {
        let active = displays.filter { $0.ddcSupported }
        guard !active.isEmpty else { return 50 }
        return active.map(\.brightness).reduce(0, +) / Double(active.count)
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
                if CGDisplayIsBuiltin(id) != 0 { continue }

                let name = DisplayManager.displayName(for: id)
                var model = DisplayModel(id: id, name: name)

                if let (val, maxVal) = DDCHelper.readBrightness(displayID: id), maxVal > 0 {
                    model.brightness    = min(max(Double(val) / Double(maxVal) * 100.0, 0), 100)
                    model.maxBrightness = Double(maxVal)
                    model.ddcSupported  = true

                    if let (cVal, cMax) = DDCHelper.readContrast(displayID: id), cMax > 0 {
                        model.contrast    = min(max(Double(cVal) / Double(cMax) * 100.0, 0), 100)
                        model.maxContrast = Double(cMax)
                    }
                    if let (vVal, vMax) = DDCHelper.readVolume(displayID: id), vMax > 0 {
                        model.volume    = min(max(Double(vVal) / Double(vMax) * 100.0, 0), 100)
                        model.maxVolume = Double(vMax)
                    }
                    if let (src, _) = DDCHelper.readInputSource(displayID: id) {
                        model.inputSource = src
                    }
                } else {
                    model.ddcSupported = false
                }
                result.append(model)
            }
            return result
        }.value

        DisplayManager.enrichDisplayNames(&models)
        return models
    }

    // MARK: - Brightness

    func setBrightness(_ brightness: Double, for displayID: CGDirectDisplayID) {
        if let idx = displays.firstIndex(where: { $0.id == displayID }) {
            displays[idx].brightness = brightness
        }
        pendingWrites[displayID]?.cancel()
        let item = DispatchWorkItem {
            DDCHelper.writeBrightness(displayID: displayID, value: Int(brightness.rounded()))
        }
        pendingWrites[displayID] = item
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    func setMasterBrightness(_ brightness: Double) {
        for display in displays where display.ddcSupported {
            setBrightness(brightness, for: display.id)
        }
    }

    // MARK: - Contrast

    func setContrast(_ contrast: Double, for displayID: CGDirectDisplayID) {
        if let idx = displays.firstIndex(where: { $0.id == displayID }) {
            displays[idx].contrast = contrast
        }
        pendingContrastWrites[displayID]?.cancel()
        let item = DispatchWorkItem {
            DDCHelper.writeContrast(displayID: displayID, value: Int(contrast.rounded()))
        }
        pendingContrastWrites[displayID] = item
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    // MARK: - Volume

    func setVolume(_ volume: Double, for displayID: CGDirectDisplayID) {
        if let idx = displays.firstIndex(where: { $0.id == displayID }) {
            displays[idx].volume = volume
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) {
            DDCHelper.writeVolume(displayID: displayID, value: Int(volume.rounded()))
        }
    }

    // MARK: - Input Source

    func setInputSource(_ source: Int, for displayID: CGDirectDisplayID) {
        if let idx = displays.firstIndex(where: { $0.id == displayID }) {
            displays[idx].inputSource = source
        }
        DispatchQueue.global(qos: .userInitiated).async {
            DDCHelper.writeInputSource(displayID: displayID, value: source)
        }
    }

    // MARK: - Presets

    func applyPreset(_ preset: BrightnessPreset) {
        setMasterBrightness(preset.brightness)
    }

    // MARK: - Power

    func setPower(on: Bool, for displayID: CGDirectDisplayID) {
        DispatchQueue.global(qos: .userInitiated).async {
            DDCHelper.setPower(displayID: displayID, on: on)
        }
    }

    // MARK: - Display name resolution

    nonisolated static func displayName(for displayID: CGDirectDisplayID) -> String {
        if let name = ioKitDisplayName(for: displayID), !name.isEmpty { return name }
        return "External Display \(displayID)"
    }

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
                        id:            displays[i].id,
                        name:          localizedName,
                        brightness:    displays[i].brightness,
                        contrast:      displays[i].contrast,
                        maxBrightness: displays[i].maxBrightness,
                        maxContrast:   displays[i].maxContrast,
                        volume:        displays[i].volume,
                        maxVolume:     displays[i].maxVolume,
                        inputSource:   displays[i].inputSource,
                        ddcSupported:  displays[i].ddcSupported,
                        isLoading:     displays[i].isLoading
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
