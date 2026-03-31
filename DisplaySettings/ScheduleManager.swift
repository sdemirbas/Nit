// ScheduleManager.swift
// Time-based automatic brightness: checks every minute, applies matching rule.

import Foundation

struct ScheduleEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var hour: Int           // 0–23
    var minute: Int         // 0–59
    var brightness: Double  // 0–100

    var displayString: String {
        String(format: "%02d:%02d  →  %d%%", hour, minute, Int(brightness.rounded()))
    }
}

@MainActor
final class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    @Published var entries: [ScheduleEntry] {
        didSet { save() }
    }
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            isEnabled ? startTimer() : stopTimer()
        }
    }

    private var timer: Timer?
    private weak var displayManager: DisplayManager?

    private enum Keys {
        static let entries = "scheduleEntries"
        static let enabled = "scheduleEnabled"
    }

    private init() {
        entries   = Self.load()
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
    }

    // MARK: - Setup

    func attach(displayManager: DisplayManager) {
        self.displayManager = displayManager
        if isEnabled { startTimer() }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        // Fire immediately, then every 60 seconds
        checkAndApply()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkAndApply() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func checkAndApply() {
        guard let dm = displayManager else { return }
        let cal = Calendar.current
        let now = Date()
        let currentHour   = cal.component(.hour,   from: now)
        let currentMinute = cal.component(.minute, from: now)

        // Find the most recent past rule relative to now (wraps around midnight)
        let sorted = entries.sorted {
            ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute)
        }
        let nowMinutes = currentHour * 60 + currentMinute
        let active = sorted.last(where: { $0.hour * 60 + $0.minute <= nowMinutes })
                  ?? sorted.last   // wrap: if before all entries, use last (yesterday's rule)
        guard let rule = active else { return }

        dm.setMasterBrightness(rule.brightness)
    }

    // MARK: - Persistence

    func addEntry(_ entry: ScheduleEntry) { entries.append(entry) }
    func deleteEntry(id: UUID) { entries.removeAll { $0.id == id } }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Keys.entries)
        }
    }

    private static func load() -> [ScheduleEntry] {
        guard let data = UserDefaults.standard.data(forKey: Keys.entries),
              let saved = try? JSONDecoder().decode([ScheduleEntry].self, from: data) else {
            return []
        }
        return saved
    }
}
