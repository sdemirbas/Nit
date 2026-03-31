// SettingsManager.swift
// Persistent app preferences: launch at login, presets, menu bar indicator.

import Foundation
import ServiceManagement

struct BrightnessPreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var brightness: Double
}

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }
    @Published var showBrightnessInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showBrightnessInMenuBar, forKey: Keys.menuBar) }
    }
    @Published var presets: [BrightnessPreset] {
        didSet { savePresets() }
    }

    private enum Keys {
        static let menuBar = "showBrightnessInMenuBar"
        static let presets = "brightnessPresets"
    }

    private init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        showBrightnessInMenuBar = UserDefaults.standard.bool(forKey: Keys.menuBar)
        presets = Self.loadPresets()
    }

    // MARK: - Actions

    func addPreset(name: String, brightness: Double) {
        presets.append(BrightnessPreset(name: name, brightness: brightness))
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
    }

    // MARK: - Private

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Settings] Launch at login error: \(error)")
        }
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Keys.presets)
        }
    }

    private static func loadPresets() -> [BrightnessPreset] {
        if let data = UserDefaults.standard.data(forKey: Keys.presets),
           let saved = try? JSONDecoder().decode([BrightnessPreset].self, from: data) {
            return saved
        }
        return [
            BrightnessPreset(name: "Day", brightness: 80),
            BrightnessPreset(name: "Evening", brightness: 50),
            BrightnessPreset(name: "Night", brightness: 20),
        ]
    }
}
