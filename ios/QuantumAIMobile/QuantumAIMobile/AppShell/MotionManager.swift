import SwiftUI
#if canImport(UIKit)
import UIKit

// Bursa Operasyon: Cihazın sallanmasını yakalayan Window eklentisi
// Not: Shake algilamasi icin iOS girisinde ShakeDetectingWindow kullanin.
// Ornek: SceneDelegate/AppDelegate icinde window = ShakeDetectingWindow(frame: UIScreen.main.bounds)

extension NSNotification.Name {
    static let deviceDidShake = NSNotification.Name("deviceDidShake")
}

final class ShakeDetectingWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

// SwiftUI için ViewModifier
struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

extension View {
    public func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}
#else
extension View {
    public func onShake(perform action: @escaping () -> Void) -> some View {
        self
    }
}
#endif
