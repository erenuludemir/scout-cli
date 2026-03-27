import SwiftUI
#if canImport(TipKit)
import TipKit
#endif
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct TrainingJourneyView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var contextualDestination: TrainingJourneyDestination?
    @State private var selectedRating = 0

    let showsCloseButton: Bool

    public init(showsCloseButton: Bool = false) {
        self.showsCloseButton = showsCloseButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                ScreenHeader(title: "Training Journey", showsBackButton: true, onBack: { dismiss() })
                progressCard
                stepContent
                actionFooter
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .background(AppBackground())
        .screenNavigationChromeHidden()
        .task {
            refreshPrerequisites()
            recordContextualHelpIfNeeded()
            selectedRating = journey.analytics.feedbackScore
        }
        .onChange(of: env.settings.isAuthenticated) { _, _ in
            refreshPrerequisites()
        }
        .onChange(of: env.market.last != nil) { _, _ in
            refreshPrerequisites()
        }
        .onChange(of: journey.analytics.feedbackScore) { _, score in
            selectedRating = score
        }
        .onChange(of: env.trainingJourney.currentStep) { _, _ in
            recordContextualHelpIfNeeded()
        }
        .navigationDestination(item: $contextualDestination) { destination in
            switch destination {
            case .dashboard:
                DashboardView()
            case .wallet:
                WalletView(showsBackButton: true)
            case .marketBridge:
                MarketBridgeView(showsBackButton: true)
            }
        }
    }

    private var journey: TrainingJourneyStore {
        env.trainingJourney
    }

    private var progressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(journey.currentStep.title)
                            .font(QAITokens.Typography.largeTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text("Kaldığın yer tutulur. Çıkıp tekrar girdiğinde aynı adımdan devam edersin.")
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("%\(Int(journey.progressValue * 100))")
                            .font(QAITokens.Typography.statValue)
                            .foregroundStyle(QAITokens.Palette.gold)
                        Text("Kalan ~\(journey.estimatedMinutesRemaining) dk")
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    }
                }

                ProgressView(value: journey.progressValue)
                    .tint(QAITokens.Palette.gold)
                    .accessibilityLabel("Training ilerleme durumu")

                HStack(spacing: 10) {
                    TrainingInfoTile(
                        title: "Kazanım",
                        value: "Canlıdan ayrı güvenli öğrenme",
                        tint: QAITokens.Palette.chipBlue
                    )
                    TrainingInfoTile(
                        title: "Rol",
                        value: journey.selectedRole.title,
                        tint: QAITokens.Palette.chipTeal
                    )
                    TrainingInfoTile(
                        title: "Süre",
                        value: "\(journey.estimatedMinutesRemaining + 4) dk",
                        tint: QAITokens.Palette.chipAmber
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch journey.currentStep {
        case .welcome:
            welcomeStep
        case .prerequisites:
            prerequisitesStep
        case .profile:
            profileStep
        case .demo:
            demoStep
        case .modules:
            modulesStep
        case .interactive:
            interactiveStep
        case .contextualHelp:
            contextualHelpStep
        case .sandbox:
            sandboxStep
        case .quiz:
            quizStep
        case .completion:
            completionStep
        }
    }

    private var actionFooter: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                if !journey.canAdvance && journey.currentStep != .completion {
                    Text(blockingMessage)
                        .font(.footnote)
                        .foregroundStyle(QAITokens.Palette.warning)
                }

                HStack(spacing: 10) {
                    PrimaryActionButton(title: "Geri", style: .secondary) {
                        journey.retreat()
                    }
                    .disabled(journey.currentStep == .welcome)
                    .opacity(journey.currentStep == .welcome ? 0.45 : 1)

                    PrimaryActionButton(title: primaryActionTitle) {
                        advance()
                    }
                    .disabled(!journey.canAdvance && journey.currentStep != .completion)
                    .opacity(!journey.canAdvance && journey.currentStep != .completion ? 0.45 : 1)
                }

                if journey.currentStep == .completion {
                    Button("Training'i Baştan Başlat") {
                        journey.resetJourney()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingSectionTitle("Karşılama ve Amaç", icon: "flag.2.crossed.fill")

                    Text("Bu training, wallet, bot ve blockchain akışlarını kontrollü sırayla kurar; kullanıcıyı gereksiz bekletmeden doğrudan iş üstünde öğrenmeye geçirir.")
                        .font(.body)
                        .foregroundStyle(QAITokens.Palette.textPrimary)

                    if env.training.guide.summary != "Kaynak bekleniyor" {
                        Text(env.training.guide.summary)
                            .font(.subheadline)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    }

                    HStack(spacing: 10) {
                        WelcomeBadge(title: "Uygun Rol", value: "Teknik / Operasyon / Yönetici")
                        WelcomeBadge(title: "Yaklaşık Süre", value: "8-20 dk")
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    TrainingSectionTitle("İlk Oturumda Göreceklerin", icon: "square.stack.3d.up.fill")
                    TrainingBullet(text: "Gerekli izinler ve cihaz hazır olma durumu tek ekranda toplanır.")
                    TrainingBullet(text: "Seviye ve role göre modüler akış oluşturulur.")
                    TrainingBullet(text: "Sandbox, mini test ve ilerleme takibi canlı işlemlerden ayrı tutulur.")
                    TrainingBullet(text: "Harici wallet doğrulaması tamamlandıktan sonra işlem akışı yine bu uygulamada sürer.")
                }
            }
        }
    }

    private var prerequisitesStep: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    TrainingSectionTitle("İzinler ve Önkoşullar", icon: "checklist.checked")
                    Text("Amaç, kullanıcıyı training ortasında hatayla durdurmamak. Bildirim, oturum, ağ ve cihaz güvenliği buradan tamamlanır.")
                        .font(.subheadline)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    TrainingChecklistRow(
                        title: "Bildirim Hazırlığı",
                        subtitle: "Uygulama içi uyarıları ve eğitim ipuçlarını almaya hazırım.",
                        isOn: prerequisiteBinding(\.notificationsReady)
                    )

                    TrainingReadinessRow(
                        title: "Hesap Durumu",
                        subtitle: journey.prerequisites.accountReady ? "Demo veya lisanslı oturum hazır." : "Oturum durumu bekleniyor.",
                        isReady: journey.prerequisites.accountReady
                    )

                    TrainingReadinessRow(
                        title: "Ağ ve Veri Akışı",
                        subtitle: journey.prerequisites.networkReady ? "Simülasyon veya canlı feed yolu hazır." : "Piyasa bağlantısı bekleniyor.",
                        isReady: journey.prerequisites.networkReady
                    )

                    TrainingReadinessRow(
                        title: "Cihaz Uyumluluğu",
                        subtitle: journey.prerequisites.deviceReady ? "Cihaz biyometrik veya parola doğrulamasını destekliyor." : "Cihaz doğrulama desteği görünmüyor.",
                        isReady: journey.prerequisites.deviceReady
                    )

                    HStack(spacing: 10) {
                        PrimaryActionButton(title: journey.prerequisites.securityVerified ? "Güvenlik Doğrulandı" : "Face ID / Parola ile Doğrula") {
                            Task { await verifySecurity() }
                        }
                        .disabled(journey.prerequisites.securityVerified)
                        .opacity(journey.prerequisites.securityVerified ? 0.55 : 1)
                    }
                }
            }

            WalletActivationPanel(
                headline: "Wallet Aktivasyonu",
                subtitle: "Binance, Coinbase Wallet, Trust Wallet ve MetaMask aktivasyonu training başlamadan doğrulanabilir.",
                onVerified: { _ in
                    journey.markInteractiveTask("wallet-activation")
                }
            )
        }
    }

    private var profileStep: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingSectionTitle("Profil / Seviye Belirleme", icon: "person.crop.circle.badge.checkmark")
                    Text("İçerik, kullanıcı seviyesi ve rolüne göre dallanır. Bu seçimler sonraki modül önerilerini ve demo tonunu etkiler.")
                        .font(.subheadline)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    TrainingChoiceGroup(title: "Seviye") {
                        ForEach(TrainingLevel.allCases) { level in
                            ChoiceChip(
                                title: level.title,
                                isSelected: journey.selectedLevel == level
                            ) {
                                journey.selectedLevel = level
                            }
                        }
                    }

                    TrainingChoiceGroup(title: "Rol") {
                        ForEach(TrainingRole.allCases) { role in
                            ChoiceChip(
                                title: role.title,
                                isSelected: journey.selectedRole == role
                            ) {
                                journey.selectedRole = role
                            }
                        }
                    }

                    TrainingChoiceGroup(title: "Akış Derinliği") {
                        ForEach(TrainingMode.allCases) { mode in
                            ChoiceChip(
                                title: mode.title,
                                isSelected: journey.selectedMode == mode
                            ) {
                                journey.selectedMode = mode
                            }
                        }
                    }
                }
            }
        }
    }

    private var demoStep: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    TrainingSectionTitle("Kısa Ürün Tanıtımı", icon: "play.rectangle.fill")
                    Text("Uzun açıklama yerine 2-5 ekranda ürünün gerçek iş akışı gösterilir. Eğitim, okumalık değil görev odaklı kalır.")
                        .font(.subheadline)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    DemoLane(title: "1. Paneli Tara", summary: "Risk modu, lisans ve feed kaynağı üstten görünür.", icon: "speedometer")
                    DemoLane(title: "2. Cüzdanı Hazırla", summary: "Ağ seç, adresi göster ve güvenli imza akışını prova et.", icon: "wallet.pass.fill")
                    DemoLane(title: "3. Senaryoyu Simüle Et", summary: "Sandbox ile gerçek veri dışı pratik yap, sonra mini test ile doğrula.", icon: "rectangle.3.group.bubble.left.fill")
                }
            }
        }
    }

    private var modulesStep: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingSectionTitle("Training Modülü Seçimi", icon: "square.grid.2x2.fill")
                    Text("Tek ağır onboarding yerine ihtiyaç duyulan modüller seçilir. Varsayılan seçimler kaldığın yere göre saklanır.")
                        .font(.subheadline)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    ForEach(TrainingModuleOption.allCases) { module in
                        ModuleSelectionRow(
                            title: module.title,
                            subtitle: module.summary,
                            isSelected: journey.selectedModules.contains(module)
                        ) {
                            journey.toggleModule(module)
                        }
                    }
                }
            }
        }
    }

    private var interactiveStep: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingSectionTitle("Adım Adım İnteraktif Eğitim", icon: "hand.tap.fill")
                    Text("Bu bölüm sadece okumalık değil; seçim, doğrulama ve görev onayıyla ilerler.")
                        .font(.subheadline)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    InteractiveTaskRow(
                        title: "Durum panelini okudum",
                        subtitle: "Çalışma modu, lisans ve veri kaynağı kartlarını gözden geçir.",
                        isDone: journey.interactiveTasks.contains("dashboard")
                    ) {
                        openContextualDestination(.dashboard, taskID: "dashboard")
                    }

                    InteractiveTaskRow(
                        title: "Bir blockchain ağı seçtim",
                        subtitle: "Wallet yüzeyinde bir ağ seçip güvenli gönderim mantığını prova et.",
                        isDone: journey.interactiveTasks.contains("network")
                    ) {
                        openContextualDestination(.wallet, taskID: "network")
                    }

                    InteractiveTaskRow(
                        title: "Güvenli işlem adımını onayladım",
                        subtitle: "Face ID / parola doğrulamasının işlem öncesinde geldiğini doğrula.",
                        isDone: journey.interactiveTasks.contains("security")
                    ) {
                        openContextualDestination(.wallet, taskID: "security")
                    }
                }
            }

            if journey.selectedModules.contains(.walletActivation) || !env.walletActivation.verifiedProviders.isEmpty {
                WalletActivationPanel(
                    headline: "Wallet Entegrasyon Görevi",
                    subtitle: "Harici wallet doğrulamasını training içinde tamamla; sonrasında işlem uygulamaya geri dönsün.",
                    onVerified: { _ in
                        journey.markInteractiveTask("wallet-verified")
                    }
                )
            }
        }
    }

    private var contextualHelpStep: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingSectionTitle("Bağlamsal İpuçları", icon: "lightbulb.max.fill")
                    Text("Yardım kalıcı bir menüye gömülmez. Kullanıcının durduğu yerde kısa, alakalı ve tekrar kontrollü biçimde görünür.")
                        .font(.subheadline)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    #if canImport(TipKit)
                    TipView(TrainingProgressTip())
                        .tipBackground(QAITokens.Palette.cardElevated)
                        .tipCornerRadius(20)
                    #else
                    TrainingFallbackHelpCard()
                    #endif

                    TrainingBullet(text: "İlerleme, kaldığın yer ve sonraki en iyi adım her ekranda görünür.")
                    TrainingBullet(text: "Wallet aktivasyonu tamamlandığında tekrar harici uygulamada kalınmaz; işlem akışı bu uygulamada sürer.")
                    TrainingBullet(text: "Dynamic Type, kontrast ve VoiceOver için tekrar erişilebilir etiketleme korunur.")
                }
            }
        }
    }

    private var sandboxStep: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingSectionTitle("Pratik / Simülasyon Alanı", icon: "shippingbox.fill")
                    Text("Riskli finans ve güvenlik akışları gerçek veriden ayrılır. Bu katman, canlı cüzdan ve canlı emir yüzeyine dokunmadan pratiği mümkün kılar.")
                        .font(.subheadline)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    HStack(spacing: 10) {
                        TrainingInfoTile(
                            title: "Bakiye",
                            value: "$\(Int(journey.sandbox.quoteBalance))",
                            tint: QAITokens.Palette.chipBlue
                        )
                        TrainingInfoTile(
                            title: "İşlem",
                            value: "\(journey.sandbox.completedTrades)",
                            tint: QAITokens.Palette.chipTeal
                        )
                    }

                    Text(journey.sandbox.lastAction)
                        .font(.footnote)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    HStack(spacing: 10) {
                        PrimaryActionButton(title: "Sandbox BUY") {
                            journey.runSandboxTrade(label: "Sandbox BUY işlemi tamamlandı")
                        }
                        PrimaryActionButton(title: "Sandbox SELL", style: .secondary) {
                            journey.runSandboxTrade(label: "Sandbox SELL işlemi tamamlandı")
                        }
                    }

                    Button("Sandbox Sıfırla") {
                        journey.resetSandbox()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quizStep: some View {
        VStack(spacing: 18) {
            ForEach(TrainingJourneyStore.quizQuestions) { question in
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        TrainingSectionTitle(question.prompt, icon: "questionmark.circle.fill")

                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            QuizOptionRow(
                                title: option,
                                isSelected: journey.quizAnswers[question.id] == index
                            ) {
                                journey.answer(questionID: question.id, optionIndex: index)
                            }
                        }
                    }
                }
            }
        }
    }

    private var completionStep: some View {
        VStack(spacing: 18) {
            TrainingSummaryCard(
                moduleCount: journey.selectedModules.count,
                quizScore: journey.quizScore,
                quizTotal: TrainingJourneyStore.quizQuestions.count,
                walletCount: env.walletActivation.verifiedProviders.count,
                helpCount: journey.analytics.helpRequests,
                nextModuleTitle: nextRecommendedModule,
                selectedRating: $selectedRating,
                onSelectRating: { score in
                    journey.submitFeedback(score: score)
                }
            )
        }
    }

    private var primaryActionTitle: String {
        journey.currentStep == .completion ? "Tamamla ve Kapat" : "Devam Et"
    }

    private var blockingMessage: String {
        switch journey.currentStep {
        case .prerequisites:
            return "Devam etmek için bildirim hazırlığını ve güvenlik doğrulamasını tamamla."
        case .modules:
            return "En az bir training modülü seç."
        case .interactive:
            return "En az üç interaktif görevi tamamla."
        case .sandbox:
            return "En az bir sandbox işlemi yap."
        case .quiz:
            return "Tüm mini test sorularını yanıtla."
        default:
            return "Bu adımı tamamla."
        }
    }

    private var nextRecommendedModule: String {
        TrainingModuleOption.allCases.first(where: { !journey.selectedModules.contains($0) })?.title ?? "Tüm temel modüller tamamlandı"
    }

    private func prerequisiteBinding(_ keyPath: WritableKeyPath<TrainingPrerequisites, Bool>) -> Binding<Bool> {
        Binding(
            get: { journey.prerequisites[keyPath: keyPath] },
            set: { newValue in
                var prerequisites = journey.prerequisites
                prerequisites[keyPath: keyPath] = newValue
                journey.prerequisites = prerequisites
            }
        )
    }

    private func refreshPrerequisites() {
        journey.refreshPrerequisites(
            accountReady: true,
            networkReady: env.runtimeUsesSimulation || env.market.last != nil || env.settings.marketBridgeEnabled,
            deviceReady: deviceSupportsOwnerAuthentication()
        )
    }

    private func verifySecurity() async {
        do {
            try await SecurityGate.verifyAction(
                reason: "Training önkoşullarını tamamlamak için Face ID, Touch ID veya cihaz parolasını kullanın."
            )
            journey.markSecurityVerified()
        } catch {
            env.metrics.recordError("training_security_verification_failed=\(error.localizedDescription)")
        }
    }

    private func recordContextualHelpIfNeeded() {
        guard journey.currentStep == .contextualHelp else { return }
        journey.recordHelpShown()
    }

    private func openContextualDestination(_ destination: TrainingJourneyDestination, taskID: String) {
        journey.markInteractiveTask(taskID)
        contextualDestination = destination
    }

    private func advance() {
        if journey.currentStep == .completion {
            journey.completeJourney()
            dismiss()
            return
        }
        journey.advance()
    }

    private func deviceSupportsOwnerAuthentication() -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        #else
        return false
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, *)
private enum TrainingJourneyDestination: String, Identifiable {
    case dashboard
    case wallet
    case marketBridge

    var id: String { rawValue }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingSectionTitle: View {
    let title: String
    let icon: String

    init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        Label(title, systemImage: icon)
            .font(QAITokens.Typography.cardTitle)
            .foregroundStyle(QAITokens.Palette.textPrimary)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingInfoTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(tint.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct WelcomeBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .padding(QAITokens.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(QAITokens.Palette.gold)
            Text(text)
                .font(QAITokens.Typography.body)
                .foregroundStyle(QAITokens.Palette.textSecondary)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingChecklistRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(subtitle)
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }
        }
        .toggleStyle(.switch)
        .tint(QAITokens.Palette.gold)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingReadinessRow: View {
    let title: String
    let subtitle: String
    let isReady: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isReady ? "checkmark.seal.fill" : "clock.badge.exclamationmark.fill")
                .foregroundStyle(isReady ? QAITokens.Palette.teal : QAITokens.Palette.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(subtitle)
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }
            Spacer()
        }
        .padding(QAITokens.Spacing.m)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingChoiceGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    content
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(isSelected ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? QAITokens.Palette.gold : QAITokens.Palette.cardElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DemoLane: View {
    let title: String
    let summary: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(QAITokens.Palette.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(summary)
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }
            Spacer()
        }
        .padding(QAITokens.Spacing.m)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ModuleSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(QAITokens.Typography.bodyStrong)
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                    Text(subtitle)
                        .font(QAITokens.Typography.body)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? QAITokens.Palette.teal : QAITokens.Palette.textSecondary)
            }
            .padding(QAITokens.Spacing.m)
            .background(isSelected ? QAITokens.Palette.chipBlue : QAITokens.Palette.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct InteractiveTaskRow: View {
    let title: String
    let subtitle: String
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(subtitle)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }

            Spacer()

            Button(action: action) {
                Text(isDone ? "Tamam" : "İşle")
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(isDone ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isDone ? QAITokens.Palette.teal : QAITokens.Palette.cardElevated)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(QAITokens.Spacing.m)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct QuizOptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? QAITokens.Palette.gold : QAITokens.Palette.textSecondary)
                Text(title)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Spacer()
            }
            .padding(QAITokens.Spacing.m)
            .background(isSelected ? QAITokens.Palette.chipAmber : QAITokens.Palette.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CompletionSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Spacer()
            Text(value)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .padding(.vertical, 2)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingFallbackHelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Yerinde Yardım")
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
            Text("İlerleme, güvenli işlem ve sandbox davranışları kısa kartlarla kullanıcıya ihtiyaç anında gösterilir.")
                .font(QAITokens.Typography.body)
                .foregroundStyle(QAITokens.Palette.textSecondary)
        }
        .padding(QAITokens.Spacing.m)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#if canImport(TipKit)
@available(iOS 17.0, macOS 14.0, *)
private struct TrainingProgressTip: Tip {
    var title: Text {
        Text("İpucu: Güvenli akış burada bitmiyor")
    }

    var message: Text? {
        Text("Harici wallet doğrulamasını tamamladıktan sonra kullanıcı işlemi yine uygulama içinden sürdürmeli.")
    }

    var image: Image? {
        safeSymbol("hand.raised.shield.fill", fallback: "shield.fill")
    }
}
#endif

private func safeSymbol(_ primary: String, fallback: String) -> Image {
    #if canImport(UIKit)
    if UIImage(systemName: primary) != nil {
        return Image(systemName: primary)
    }
    #endif
    return Image(systemName: fallback)
}
