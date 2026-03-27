import Foundation
import SwiftUI

@MainActor
public final class PartnerBrandingEngine: ObservableObject {
    public static let shared = PartnerBrandingEngine()

    @Published public var currentPartnerName = "BURSA HQ"
    @Published public var primaryThemeColor: Color = QAITheme.accent
    @Published public var partnerLogoID = "bursa_default_logo"

    private init() {}

    public func applyPartnerTheme(partnerID: String) {
        if partnerID.uppercased().contains("BANK") {
            currentPartnerName = "OSMANGAZI BANKASI"
            primaryThemeColor = QAITheme.panelBlue
            partnerLogoID = "bank_shield_logo"
        } else if partnerID.uppercased().contains("INVEST") {
            currentPartnerName = "BURSA INVEST GROUP"
            primaryThemeColor = QAITheme.warning
            partnerLogoID = "invest_hall_logo"
        } else {
            currentPartnerName = "BURSA HQ ENTERPRISE"
            primaryThemeColor = QAITheme.accent
            partnerLogoID = "bursa_default_logo"
        }

        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "BRANDING_APPLIED: \(currentPartnerName)",
            veri: ["partner_id": partnerID]
        )
    }
}
