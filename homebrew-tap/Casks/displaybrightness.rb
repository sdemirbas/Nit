cask "displaybrightness" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256_UPDATE_AFTER_FIRST_RELEASE"

  url "https://github.com/YOUR_GITHUB_USERNAME/DisplaySettings/releases/download/v#{version}/DisplaySettings-#{version}.zip"
  name "DisplaySettings"
  desc "Menu bar app to control external display brightness via DDC/CI"
  homepage "https://github.com/YOUR_GITHUB_USERNAME/DisplaySettings"

  app "DisplaySettings.app"

  # Automatically remove quarantine flag (avoids Gatekeeper warning for unsigned app)
  postflight do
    system_command "/usr/bin/xattr",
      args: ["-dr", "com.apple.quarantine", "#{appdir}/DisplaySettings.app"],
      sudo: false
  end

  zap trash: "~/Library/Preferences/com.displaySettings.DisplaySettings.plist"
end
