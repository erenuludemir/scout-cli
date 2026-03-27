import SwiftUI
#if canImport(WebKit)
import WebKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

@available(iOS 17.0, macOS 14.0, *)
struct TrainingDemoCenterView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedSection: TrainingCenterSection = .demo

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                sectionPicker

                switch selectedSection {
                case .demo:
                    demoSection
                case .test:
                    testSection
                case .guide:
                    guideSection
                }
            }
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Test ve Demo Merkezi")
                    .font(QAITheme.heroTitleFont)
                    .foregroundStyle(QAITheme.textPrimary)
                Text("Kullanıcı tarafındaki akışı gösterir. İç sistem, servis ve teknik uygulama süreçleri bu merkezde özellikle gizlenir.")
                    .font(QAITheme.bodyFont)
                    .foregroundStyle(QAITheme.textSecondary)
            }

            Spacer()

            AppMarkView(size: 42)
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 8) {
            ForEach(TrainingCenterSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.icon)
                        Text(section.title)
                    }
                    .font(QAITheme.buttonFont)
                    .foregroundStyle(selectedSection == section ? QAITheme.background : QAITheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, QAITheme.compactButtonVerticalPadding)
                    .background(selectedSection == section ? QAITheme.accent : QAITheme.surfaceMuted.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var demoSection: some View {
        VStack(spacing: 14) {
            TrainingCenterNote(
                title: "Demo amacı",
                message: "Yeni bir kişi uygulamayı açtığında önce ne kazandığını, sonra hangi güvenli adımlarla ilerleyeceğini görür."
            )

            TrainingScenarioCard(
                step: "1",
                title: "Paneli tanı",
                summary: "Durum, sembol ve çalışma modunu gör. Bu adım sadece genel görünümü tanıtır.",
                result: "Kullanıcı hangi ekranda ne yaptığını anlar."
            )

            TrainingScenarioCard(
                step: "2",
                title: "Cüzdan ve doğrulama",
                summary: "Binance, Coinbase Wallet, Trust Wallet veya MetaMask aktivasyonunu başlat; onaydan sonra akış uygulamada devam eder.",
                result: "Face ID / parola ile güvenli doğrulama mantığı görünür olur."
            )

            TrainingScenarioCard(
                step: "3",
                title: "Sandbox ve mini alıştırma",
                summary: "Gerçek işlem üretmeden sandbox içinde akış prova edilir.",
                result: "Kullanıcı hata korkusu olmadan işlem sırasını öğrenir."
            )

            HStack(spacing: 10) {
                TrainingQuickActionTile(
                    title: "Training Aç",
                    subtitle: "Karşılama + sandbox",
                    tint: QAITheme.panelBlue,
                    destination: TrainingJourneyView()
                )

                TrainingQuickActionTile(
                    title: "Wallet Aç",
                    subtitle: "\(env.walletActivation.verifiedProviders.count) doğrulandı",
                    tint: QAITheme.success,
                    destination: WalletView()
                )

                TrainingQuickActionTile(
                    title: "Botlar Aç",
                    subtitle: "Demo senaryoları",
                    tint: QAITheme.accent,
                    destination: TradeView()
                )
            }
        }
    }

    private var testSection: some View {
        VStack(spacing: 14) {
            TrainingCenterNote(
                title: "Test amacı",
                message: "Kullanıcının işlem öncesi hangi adımları kontrol etmesi gerektiği açık görünür; burada iç servis süreçleri değil yalnızca kullanıcı aksiyonları vardır."
            )

            TrainingChecklistCard(
                title: "Hazırlık",
                items: [
                    .init(title: "Dashboard durumu görünüyor", detail: "Sembol, mod ve temel durum kartları ekranda okunmalı."),
                    .init(title: "Wallet adresi okunuyor", detail: "Adres gösterimi ve kopyalama akışı çalışmalı."),
                    .init(title: "Harici wallet dönüşü anlaşılır", detail: "Doğrulama harici wallet'ta başlasa da işlem uygulamada sürmeli.")
                ]
            )

            TrainingChecklistCard(
                title: "Güvenli doğrulama",
                items: [
                    .init(title: "Face ID / parola tetikleniyor", detail: "İşlem öncesi kullanıcıdan biyometrik veya cihaz parolası istenir."),
                    .init(title: "Gerçek işlem yerine prova var", detail: "Önce sandbox veya demo senaryosu ile akış görülür."),
                    .init(title: "Kaldığın yer saklanıyor", detail: "Training tekrar açıldığında aynı adımdan devam edilir.")
                ]
            )

            TrainingChecklistCard(
                title: "Beklenen sonuç",
                items: [
                    .init(title: "Kişi akışı anlar", detail: "Hangi sırayla ilerleyeceğini görür."),
                    .init(title: "Canlı risk oluşmaz", detail: "Demo ve test akışları gerçek işlem üretmez."),
                    .init(title: "İşlem adımları görünür olur", detail: "Aç, doğrula, prova et, sonra ilerle sırası netleşir.")
                ]
            )
        }
    }

    @ViewBuilder
    private var guideSection: some View {
        VStack(spacing: 14) {
            TrainingCenterNote(
                title: "Revize HTML sürümü",
                message: "Yüklediğin `TrainingV140721.html` dosyası kullanıcı odaklı yeni sürüm olarak uygulama içine alındı. Bu görünüm teknik runbook ve iç süreçleri değil, Test ve Demo akışını gösterir."
            )

            if let document = TrainingBundleResource.trainingHTMLDocument,
               let url = TrainingBundleResource.trainingHTMLURL {
                PlatformHTMLFileView(html: document.html, baseURL: document.baseURL)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 760)
                    .frame(height: 760)
                    .clipped()

                Link(destination: url) {
                    Label("HTML Rehberini Dışarıda Aç", systemImage: "doc.text")
                        .font(QAITheme.buttonFont)
                        .foregroundStyle(QAITheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, QAITheme.compactButtonVerticalPadding)
                        .background(QAITheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TrainingV140721.html bulunamadı")
                        .font(QAITheme.sectionTitleFont)
                        .foregroundStyle(QAITheme.textPrimary)
                    Text("Kaynak dosya uygulama içinde çözümlenemedi.")
                        .font(QAITheme.bodyFont)
                        .foregroundStyle(QAITheme.textSecondary)
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private enum TrainingCenterSection: String, CaseIterable, Identifiable {
    case demo
    case test
    case guide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .demo: return "Demo"
        case .test: return "Test"
        case .guide: return "Rehber"
        }
    }

    var icon: String {
        switch self {
        case .demo: return "play.rectangle"
        case .test: return "checklist"
        case .guide: return "doc.text"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingCenterNote: View {
    let title: String
    let message: String

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QAITheme.sectionTitleFont)
                .foregroundStyle(QAITheme.textPrimary)
            Text(message)
                .font(QAITheme.bodyFont)
                .foregroundStyle(QAITheme.textSecondary)
        }
        .padding(12)
        .background(QAITheme.surfaceMuted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }

    var body: some View { bodyView }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingScenarioCard: View {
    let step: String
    let title: String
    let summary: String
    let result: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(QAITheme.background)
                .frame(width: 34, height: 34)
                .background(QAITheme.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(QAITheme.sectionTitleFont)
                    .foregroundStyle(QAITheme.textPrimary)
                Text(summary)
                    .font(QAITheme.bodyFont)
                    .foregroundStyle(QAITheme.textSecondary)
                Text(result)
                    .font(QAITheme.captionFont)
                    .foregroundStyle(QAITheme.accentSoft)
            }
        }
        .padding(12)
        .background(QAITheme.surfaceMuted.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingChecklistItem: Identifiable {
    let title: String
    let detail: String
    var id: String { title }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingChecklistCard: View {
    let title: String
    let items: [TrainingChecklistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(QAITheme.sectionTitleFont)
                .foregroundStyle(QAITheme.textPrimary)

            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(QAITheme.success)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(QAITheme.buttonFont)
                            .foregroundStyle(QAITheme.textPrimary)
                        Text(item.detail)
                            .font(QAITheme.bodyFont)
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(QAITheme.surfaceMuted.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingQuickActionTile<Destination: View>: View {
    let title: String
    let subtitle: String
    let tint: Color
    let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(QAITheme.sectionTitleFont)
                    .foregroundStyle(QAITheme.textPrimary)
                Text(subtitle)
                    .font(QAITheme.captionFont)
                    .foregroundStyle(QAITheme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#if canImport(WebKit) && canImport(UIKit)
@available(iOS 17.0, macOS 14.0, *)
private struct PlatformHTMLFileView: UIViewRepresentable {
    final class Coordinator {
        var lastSignature: Int?
    }

    let html: String
    let baseURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .never
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let signature = html.hashValue ^ baseURL.path.hashValue
        guard context.coordinator.lastSignature != signature else { return }
        context.coordinator.lastSignature = signature
        view.loadHTMLString(html, baseURL: baseURL)
    }
}
#elseif canImport(WebKit) && canImport(AppKit)
@available(iOS 17.0, macOS 14.0, *)
private struct PlatformHTMLFileView: NSViewRepresentable {
    final class Coordinator {
        var lastSignature: Int?
    }

    let html: String
    let baseURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let signature = html.hashValue ^ baseURL.path.hashValue
        guard context.coordinator.lastSignature != signature else { return }
        context.coordinator.lastSignature = signature
        view.loadHTMLString(html, baseURL: baseURL)
    }
}
#else
@available(iOS 17.0, macOS 14.0, *)
private struct PlatformHTMLFileView: View {
    let html: String
    let baseURL: URL

    var body: some View {
        Link(destination: baseURL) {
            Label("HTML rehberini dışarıda aç", systemImage: "safari")
                .font(QAITheme.buttonFont)
                .foregroundStyle(QAITheme.accent)
        }
    }
}
#endif
