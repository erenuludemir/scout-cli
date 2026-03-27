import SwiftUI

public extension View {
    @ViewBuilder
    func screenNavigationChromeHidden() -> some View {
#if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
#else
        self
#endif
    }
}
