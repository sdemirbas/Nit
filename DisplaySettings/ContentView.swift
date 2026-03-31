// ContentView.swift
// SwiftUI popover UI for DisplaySettings menu bar app.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var displayManager: DisplayManager
    @ObservedObject  private var settings = SettingsManager.shared
    @StateObject     private var updateChecker = UpdateChecker()

    @State private var showSettings  = false
    @State private var showAddPreset = false
    @State private var newPresetName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !settings.presets.isEmpty {
                presetsBar
                Divider()
            }

            let ddcDisplays = displayManager.displays.filter { $0.ddcSupported }
            if ddcDisplays.count > 1 {
                masterSlider
                Divider()
            }

            if displayManager.displays.isEmpty && !displayManager.isRefreshing {
                noDisplaysView
            } else {
                displayListView
            }

            Divider()
            footer
        }
        .frame(width: 300)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showAddPreset) { addPresetSheet }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "display.2")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Display Settings")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Settings")

            Button {
                Task { await displayManager.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .rotationEffect(.degrees(displayManager.isRefreshing ? 360 : 0))
                    .animation(
                        displayManager.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: displayManager.isRefreshing
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Refresh displays")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Presets Bar

    private var presetsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(settings.presets) { preset in
                    Button {
                        displayManager.applyPreset(preset)
                    } label: {
                        Text(preset.name)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("\(Int(preset.brightness.rounded()))% brightness")
                }

                Button {
                    newPresetName = "Preset \(settings.presets.count + 1)"
                    showAddPreset = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Save current brightness as preset")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Master Slider

    private var masterSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 18)
                Text("All Displays")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(displayManager.masterBrightness.rounded()))%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 32, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Image(systemName: "sun.min").font(.system(size: 10)).foregroundColor(.secondary)
                Slider(
                    value: Binding(
                        get: { displayManager.masterBrightness },
                        set: { displayManager.setMasterBrightness($0) }
                    ),
                    in: 0...100, step: 1
                )
                Image(systemName: "sun.max").font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State

    private var noDisplaysView: some View {
        VStack(spacing: 8) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No external displays found")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Display List

    private var displayListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach($displayManager.displays) { $display in
                    DisplayCardView(display: $display, displayManager: displayManager)
                    if display.id != displayManager.displays.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
        .frame(maxHeight: 400)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("v\(updateChecker.currentVersion)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if updateChecker.updateAvailable, let latest = updateChecker.latestVersion {
                Button {
                    NSWorkspace.shared.open(updateChecker.releasesURL)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 10))
                        Text("v\(latest) available").font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Add Preset Sheet

    private var addPresetSheet: some View {
        VStack(spacing: 16) {
            Text("Save Preset")
                .font(.headline)
            TextField("Name", text: $newPresetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            Text("Brightness: \(Int(displayManager.masterBrightness.rounded()))%")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button("Cancel") { showAddPreset = false }
                Button("Save") {
                    settings.addPreset(
                        name: newPresetName.trimmingCharacters(in: .whitespaces),
                        brightness: displayManager.masterBrightness
                    )
                    showAddPreset = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 280)
    }
}

// MARK: - DisplayCardView

struct DisplayCardView: View {
    @Binding var display: DisplayModel
    let displayManager: DisplayManager
    @State private var showContrast     = false
    @State private var showVolume       = false
    @State private var showPowerConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name row
            HStack(spacing: 8) {
                Image(systemName: "display")
                    .font(.system(size: 13))
                    .foregroundColor(.accentColor)
                    .frame(width: 18)
                Text(display.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()

                if display.isLoading {
                    ProgressView().scaleEffect(0.6).frame(width: 20, height: 16)
                } else if display.ddcSupported {
                    Text("\(Int(display.brightness.rounded()))%")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 32, alignment: .trailing)

                    // Toggle contrast
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showContrast.toggle() }
                    } label: {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 11))
                            .foregroundColor(showContrast ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showContrast ? "Hide contrast" : "Adjust contrast")

                    // Toggle volume (only if monitor has speakers)
                    if display.volume >= 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showVolume.toggle() }
                        } label: {
                            Image(systemName: showVolume ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 11))
                                .foregroundColor(showVolume ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(showVolume ? "Hide volume" : "Adjust volume")
                    }

                    // Power off button
                    Button { showPowerConfirm = true } label: {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Put display to sleep")
                    .confirmationDialog(
                        "Put \"\(display.name)\" to sleep?",
                        isPresented: $showPowerConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Sleep Display", role: .destructive) {
                            displayManager.setPower(on: false, for: display.id)
                        }
                    }
                }
            }

            // Sliders
            if display.isLoading {
                Slider(value: .constant(50), in: 0...100).disabled(true).opacity(0.4)
            } else if display.ddcSupported {
                brightnessSlider
                if showContrast {
                    contrastSlider
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 10)).foregroundColor(.orange)
                    Text("DDC not supported").font(.system(size: 11)).foregroundColor(.secondary)
                }
                .help("This display does not support DDC/CI brightness control")
            }

            // Volume slider
            if display.ddcSupported && display.volume >= 0 && showVolume {
                volumeSlider
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var brightnessSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.min").font(.system(size: 10)).foregroundColor(.secondary)
            Slider(
                value: Binding(
                    get: { display.brightness },
                    set: { displayManager.setBrightness($0, for: display.id) }
                ),
                in: 0...100, step: 1
            )
            Image(systemName: "sun.max").font(.system(size: 10)).foregroundColor(.secondary)
        }
    }

    private var contrastSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.lefthalf.filled").font(.system(size: 10)).foregroundColor(.secondary)
            Slider(
                value: Binding(
                    get: { display.contrast },
                    set: { displayManager.setContrast($0, for: display.id) }
                ),
                in: 0...100, step: 1
            )
            Image(systemName: "circle.righthalf.filled").font(.system(size: 10)).foregroundColor(.secondary)
        }
    }

    private var volumeSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker").font(.system(size: 10)).foregroundColor(.secondary)
            Slider(
                value: Binding(
                    get: { max(display.volume, 0) },
                    set: { displayManager.setVolume($0, for: display.id) }
                ),
                in: 0...100, step: 1
            )
            Image(systemName: "speaker.wave.3").font(.system(size: 10)).foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DisplayManager())
}
