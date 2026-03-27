import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

public final class MarginCallService: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private let limit: Double = 100.0
    
    public init() {}

    public func checkBalance(_ currentBalance: Double) {
        if currentBalance < limit {
            triggerEmergencyAlarm()
        }
    }

    private func triggerEmergencyAlarm() {
        guard let url = ResourceBundle.current.url(forResource: "alarm", withExtension: "mp3") else {
            triggerEmergencyHaptics()
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
            triggerEmergencyHaptics()
        } catch {
            triggerEmergencyHaptics()
        }
    }

    private func triggerEmergencyHaptics() {
        #if canImport(UIKit)
        // Haptic feedback still works even when the optional audio asset is not bundled.
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        #endif
    }
    
    public func silence() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    deinit {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
