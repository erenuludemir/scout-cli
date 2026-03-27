import SwiftUI

public enum QAINavigationTitleMode {
    case inline
    case large
}

extension View {
    @ViewBuilder
    public func qaiNavigationTitleDisplayMode(_ mode: QAINavigationTitleMode) -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        switch mode {
        case .inline:
            self.navigationBarTitleDisplayMode(.inline)
        case .large:
            self.navigationBarTitleDisplayMode(.large)
        }
        #else
        self
        #endif
    }
}
