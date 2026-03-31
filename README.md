# DisplaySettings

macOS menu bar app for controlling external display brightness via DDC/CI.

Works with LG, Samsung, and other DDC-compatible monitors connected via DisplayPort or HDMI on Apple Silicon Macs.

## Features

- Instant brightness control from the menu bar
- DDC/CI protocol — no drivers needed
- Supports multiple external displays
- Lightweight, no Dock icon

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon Mac (M1/M2/M3/M4)
- External display connected via DisplayPort or HDMI with DDC/CI support

## Install

### Homebrew (recommended)

```bash
brew tap sdemirbas/displaybrightness
brew install --cask displaybrightness
```

### Manual

1. Download the latest `DisplaySettings.zip` from [Releases](https://github.com/sdemirbas/DisplaySettings/releases)
2. Extract and drag `DisplaySettings.app` to `/Applications`
3. First launch: right-click → Open (to bypass Gatekeeper)

## Usage

Click the display icon in the menu bar to open the brightness panel. Each connected external display shows a slider.

## Build from source

```bash
git clone https://github.com/sdemirbas/DisplaySettings.git
cd DisplaySettings
xcodebuild -project DisplaySettings.xcodeproj -scheme DisplaySettings -configuration Release build
```

## License

MIT
