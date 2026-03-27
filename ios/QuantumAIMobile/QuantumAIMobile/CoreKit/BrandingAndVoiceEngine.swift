import Foundation
import SwiftUI

public final class BrandingAndVoiceEngine: ObservableObject {
    public static let shared = BrandingAndVoiceEngine()
    @Published public var partnerName = "Bursa Crypto HQ"
    @Published public var primaryColor = Color.green
    @Published public var brandLogo = "hexagon.fill"
    @Published var isListening = false
}
