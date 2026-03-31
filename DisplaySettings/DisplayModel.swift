import Foundation
import CoreGraphics

struct DisplayModel: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    var brightness: Double   // 0–100
    var contrast: Double     // 0–100
    var maxBrightness: Double
    var maxContrast: Double
    var volume: Double        // 0–100, -1 if not supported
    var maxVolume: Double
    var inputSource: Int      // DDC VCP 0x60 value, -1 if unknown
    var ddcSupported: Bool
    var isLoading: Bool

    init(
        id: CGDirectDisplayID,
        name: String,
        brightness: Double = 50,
        contrast: Double = 50,
        maxBrightness: Double = 100,
        maxContrast: Double = 100,
        volume: Double = -1,
        maxVolume: Double = 100,
        inputSource: Int = -1,
        ddcSupported: Bool = true,
        isLoading: Bool = false
    ) {
        self.id = id
        self.name = name
        self.brightness = brightness
        self.contrast = contrast
        self.maxBrightness = maxBrightness
        self.maxContrast = maxContrast
        self.volume = volume
        self.maxVolume = maxVolume
        self.inputSource = inputSource
        self.ddcSupported = ddcSupported
        self.isLoading = isLoading
    }
}
