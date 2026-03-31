cask "displaybrightness" do
  version "1.1.0"
  sha256 "bc9a4ce404ef5dac6f1f71c00bdf824dff5edd1cc93c73ae22c04c9d26c3783d"

  url "https://github.com/sdemirbas/DisplaySettings/releases/download/v#{version}/DisplaySettings-#{version}.zip"
  name "DisplaySettings"
  desc "Menu bar app to control external display brightness via DDC/CI"
  homepage "https://github.com/sdemirbas/DisplaySettings"

  app "DisplaySettings.app"

  # Automatically remove quarantine flag (avoids Gatekeeper warning for unsigned app)
  postflight do
    system_command "/usr/bin/xattr",
      args: ["-dr", "com.apple.quarantine", "#{appdir}/DisplaySettings.app"],
      sudo: false
  end

  zap trash: "~/Library/Preferences/com.displaySettings.DisplaySettings.plist"
end
