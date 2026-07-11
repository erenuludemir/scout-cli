import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct AppBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            if let backdrop = BackdropResource.image {
                backdrop
                    .resizable()
                    .scaledToFill()
                    .opacity(0.34)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.68),
                    QAITokens.Palette.backgroundTop.opacity(0.82),
                    QAITokens.Palette.backgroundBottom.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    QAITokens.Palette.backgroundGlow.opacity(0.42),
                    Color.clear,
                    Color.black.opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.06)
        }
        .ignoresSafeArea()
    }
}

private enum BackdropResource {
    static var image: Image? {
        guard let url = Bundle.module.url(forResource: "quantum-backdrop", withExtension: "jpg", subdirectory: "Backgrounds") else {
            return nil
        }

        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}
