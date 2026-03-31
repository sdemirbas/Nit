import Foundation
import CoreGraphics

struct DisplayModel: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    var brightness: Double       // 0–100
    var maxBrightness: Double    // DDC reported max (usually 100)
    var ddcSupported: Bool
    var isLoading: Bool

    init(
        id: CGDirectDisplayID,
        name: String,
        brightness: Double = 50,
        maxBrightness: Double = 100,
        ddcSupported: Bool = true,
        isLoading: Bool = false
    ) {
        self.id = id
        self.name = name
        self.brightness = brightness
        self.maxBrightness = maxBrightness
        self.ddcSupported = ddcSupported
        self.isLoading = isLoading
    }
}
