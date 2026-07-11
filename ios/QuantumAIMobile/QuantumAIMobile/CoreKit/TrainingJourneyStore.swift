import Foundation
import OSLog

public enum TrainingJourneyStep: Int, CaseIterable, Identifiable, Codable, Sendable {
    case welcome
    case prerequisites
    case profile
    case demo
    case modules
    case interactive
    case contextualHelp
    case sandbox
    case quiz
    case completion

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .welcome: return "Karşılama"
        case .prerequisites: return "Önkoşullar"
        case .profile: return "Profil"
        case .demo: return "Kısa Demo"
        case .modules: return "Modül Seçimi"
        case .interactive: return "İnteraktif Eğitim"
        case .contextualHelp: return "Yardım Katmanı"
        case .sandbox: return "Sandbox"
        case .quiz: return "Mini Test"
        case .completion: return "Tamamlama"
        }
    }
}

public enum TrainingLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case beginner
    case intermediate
    case advanced

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .beginner: return "Başlangıç"
        case .intermediate: return "Orta"
        case .advanced: return "İleri"
        }
    }
}

public enum TrainingRole: String, CaseIterable, Identifiable, Codable, Sendable {
    case technical
    case operations
    case executive

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .technical: return "Teknik"
        case .operations: return "Operasyon"
        case .executive: return "Yönetici"
        }
    }
}

public enum TrainingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case quickTour
    case taskBased
    case deepDive

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .quickTour: return "Hızlı Tur"
        case .taskBased: return "Görev Bazlı"
        case .deepDive: return "Derin Eğitim"
        }
    }
}

public enum TrainingModuleOption: String, CaseIterable, Identifiable, Codable, Sendable {
    case fundamentals
    case advancedFeatures
    case scenarios
    case security
    case sandbox
    case walletActivation

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fundamentals: return "Temel Kullanım"
        case .advancedFeatures: return "Gelişmiş Özellikler"
        case .scenarios: return "Senaryo Görevleri"
        case .security: return "Güvenlik Eğitimi"
        case .sandbox: return "Test / Sandbox"
        case .walletActivation: return "Referans Doğrulama"
        }
    }

    public var summary: String {
        switch self {
        case .fundamentals: return "Panelin ana akışını ve temel komutları öğren."
        case .advancedFeatures: return "Preset, market bridge ve gelişmiş kontrol katmanlarını aç."
        case .scenarios: return "Gerçek görev benzeri senaryo kartları ile ilerle."
        case .security: return "Face ID, doğrulama ve güvenli işlem akışını tamamla."
        case .sandbox: return "Risk üretmeden ayrı model üzerinde pratik yap."
        case .walletActivation: return "Harici referans uygulamalarının geri dönüş ve doğrulama akışını gözden geçir."
        }
    }
}

public struct TrainingPrerequisites: Codable, Sendable, Equatable {
    public var notificationsReady = false
    public var accountReady = false
    public var networkReady = false
    public var deviceReady = false
    public var securityVerified = false

    public var isComplete: Bool {
        notificationsReady && accountReady && networkReady && deviceReady && securityVerified
    }
}

public struct TrainingSandboxState: Codable, Sendable {
    public var quoteBalance: Double = 5_000
    public var completedTrades = 0
    public var lastAction = "Henüz sandbox işlemi yapılmadı."

    public var isComplete: Bool {
        completedTrades > 0
    }
}

public struct TrainingAnalyticsSnapshot: Codable, Sendable {
    public var stepVisits: [String: Int] = [:]
    public var helpRequests = 0
    public var completionCount = 0
    public var feedbackScore = 0
}

public struct TrainingQuizQuestion: Identifiable, Hashable, Sendable {
    public let id: String
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int
}

private struct TrainingJourneySnapshot: Codable {
    var currentStep: TrainingJourneyStep
    var selectedLevel: TrainingLevel
    var selectedRole: TrainingRole
    var selectedMode: TrainingMode
    var selectedModules: [TrainingModuleOption]
    var prerequisites: TrainingPrerequisites
    var interactiveTasks: [String]
    var sandbox: TrainingSandboxState
    var quizAnswers: [String: Int]
    var analytics: TrainingAnalyticsSnapshot
    var hasCompletedJourney: Bool
}

@MainActor
public final class TrainingJourneyStore: ObservableObject {
    private enum Key {
        static let snapshot = "qai.training.snapshot"
    }

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.quantumai.mobile", category: "training")

    @Published public var currentStep: TrainingJourneyStep {
        didSet {
            recordStepVisit(currentStep)
            persist()
        }
    }

    @Published public var selectedLevel: TrainingLevel {
        didSet { persist() }
    }

    @Published public var selectedRole: TrainingRole {
        didSet { persist() }
    }

    @Published public var selectedMode: TrainingMode {
        didSet { persist() }
    }

    @Published public var selectedModules: Set<TrainingModuleOption> {
        didSet { persist() }
    }

    @Published public var prerequisites: TrainingPrerequisites {
        didSet { persist() }
    }

    @Published public var interactiveTasks: Set<String> {
        didSet { persist() }
    }

    @Published public var sandbox: TrainingSandboxState {
        didSet { persist() }
    }

    @Published public var quizAnswers: [String: Int] {
        didSet { persist() }
    }

    @Published public var analytics: TrainingAnalyticsSnapshot {
        didSet { persist() }
    }

    @Published public var hasCompletedJourney: Bool {
        didSet { persist() }
    }

    public static let quizQuestions: [TrainingQuizQuestion] = [
        TrainingQuizQuestion(
            id: "mode",
            prompt: "Riskli işlem denemeleri nerede yapılmalı?",
            options: ["Canlı modda", "Sandbox içinde", "Sadece market bridge ekranında"],
            correctIndex: 1
        ),
        TrainingQuizQuestion(
            id: "security",
            prompt: "Doğrulama sonrası işlem akışı nerede devam etmeli?",
            options: ["Harici cüzdan içinde", "Mevcut uygulama içinde", "Sadece PDF rehberde"],
            correctIndex: 1
        ),
        TrainingQuizQuestion(
            id: "progress",
            prompt: "Training akışında görünür olması gereken unsur hangisi?",
            options: ["Sadece logo", "İlerleme ve kaldığın yer", "Yalnızca teknik loglar"],
            correctIndex: 1
        )
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let raw = defaults.data(forKey: Key.snapshot),
            let snapshot = try? JSONDecoder().decode(TrainingJourneySnapshot.self, from: raw)
        {
            currentStep = snapshot.currentStep
            selectedLevel = snapshot.selectedLevel
            selectedRole = snapshot.selectedRole
            selectedMode = snapshot.selectedMode
            selectedModules = Set(snapshot.selectedModules)
            prerequisites = snapshot.prerequisites
            interactiveTasks = Set(snapshot.interactiveTasks)
            sandbox = snapshot.sandbox
            quizAnswers = snapshot.quizAnswers
            analytics = snapshot.analytics
            hasCompletedJourney = snapshot.hasCompletedJourney
        } else {
            currentStep = .welcome
            selectedLevel = .beginner
            selectedRole = .technical
            selectedMode = .quickTour
            selectedModules = [.fundamentals, .sandbox]
            prerequisites = TrainingPrerequisites()
            interactiveTasks = []
            sandbox = TrainingSandboxState()
            quizAnswers = [:]
            analytics = TrainingAnalyticsSnapshot()
            hasCompletedJourney = false
            recordStepVisit(.welcome)
            persist()
        }
    }

    public var shouldPresentOnLaunch: Bool {
        !hasCompletedJourney
    }

    public var progressValue: Double {
        Double(currentStep.rawValue + 1) / Double(TrainingJourneyStep.allCases.count)
    }

    public var estimatedMinutesRemaining: Int {
        max((TrainingJourneyStep.allCases.count - currentStep.rawValue - 1) * 2, 1)
    }

    public var canAdvance: Bool {
        switch currentStep {
        case .prerequisites:
            return prerequisites.isComplete
        case .modules:
            return !selectedModules.isEmpty
        case .interactive:
            return interactiveTasks.count >= 3
        case .sandbox:
            return sandbox.isComplete
        case .quiz:
            return quizAnswers.count == Self.quizQuestions.count
        default:
            return true
        }
    }

    public var quizScore: Int {
        Self.quizQuestions.reduce(0) { partial, question in
            partial + (quizAnswers[question.id] == question.correctIndex ? 1 : 0)
        }
    }

    public var selectedModuleTitles: [String] {
        selectedModules
            .map(\.title)
            .sorted()
    }

    public var blockingReason: String? {
        guard !canAdvance && currentStep != .completion else { return nil }

        switch currentStep {
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

    public func refreshPrerequisites(accountReady: Bool, networkReady: Bool, deviceReady: Bool) {
        let updated = TrainingPrerequisites(
            notificationsReady: prerequisites.notificationsReady,
            accountReady: accountReady,
            networkReady: networkReady,
            deviceReady: deviceReady,
            securityVerified: prerequisites.securityVerified
        )

        guard updated != prerequisites else { return }
        prerequisites = updated
    }

    public func markSecurityVerified() {
        guard !prerequisites.securityVerified else { return }
        var updated = prerequisites
        updated.securityVerified = true
        prerequisites = updated
    }

    public func toggleModule(_ module: TrainingModuleOption) {
        if selectedModules.contains(module) {
            selectedModules.remove(module)
        } else {
            selectedModules.insert(module)
        }
        analytics.stepVisits["module.\(module.rawValue)", default: 0] += 1
        persist()
    }

    public func markInteractiveTask(_ id: String) {
        guard !interactiveTasks.contains(id) else { return }
        interactiveTasks.insert(id)
        persist()
    }

    public func recordHelpShown() {
        analytics.helpRequests += 1
        persist()
    }

    public func runSandboxTrade(label: String) {
        sandbox.completedTrades += 1
        sandbox.quoteBalance = max(sandbox.quoteBalance - 250, 0)
        sandbox.lastAction = label
        persist()
    }

    public func resetSandbox() {
        sandbox = TrainingSandboxState()
    }

    public func answer(questionID: String, optionIndex: Int) {
        quizAnswers[questionID] = optionIndex
        persist()
    }

    public func submitFeedback(score: Int) {
        analytics.feedbackScore = score
        persist()
    }

    public func advance() {
        guard canAdvance else { return }
        guard currentStep != .completion else {
            completeJourney()
            return
        }
        currentStep = TrainingJourneyStep(rawValue: currentStep.rawValue + 1) ?? .completion
    }

    public func retreat() {
        guard currentStep.rawValue > 0 else { return }
        currentStep = TrainingJourneyStep(rawValue: currentStep.rawValue - 1) ?? .welcome
    }

    public func completeJourney() {
        hasCompletedJourney = true
        analytics.completionCount += 1
        persist()
        logger.info("training_completed modules=\(self.selectedModules.count)")
    }

    public func resetJourney() {
        currentStep = .welcome
        selectedLevel = .beginner
        selectedRole = .technical
        selectedMode = .quickTour
        selectedModules = [.fundamentals, .sandbox]
        prerequisites = TrainingPrerequisites()
        interactiveTasks = []
        sandbox = TrainingSandboxState()
        quizAnswers = [:]
        hasCompletedJourney = false
        recordStepVisit(.welcome)
        persist()
    }

    private func recordStepVisit(_ step: TrainingJourneyStep) {
        analytics.stepVisits[step.title, default: 0] += 1
    }

    private func persist() {
        let snapshot = TrainingJourneySnapshot(
            currentStep: currentStep,
            selectedLevel: selectedLevel,
            selectedRole: selectedRole,
            selectedMode: selectedMode,
            selectedModules: Array(selectedModules),
            prerequisites: prerequisites,
            interactiveTasks: Array(interactiveTasks),
            sandbox: sandbox,
            quizAnswers: quizAnswers,
            analytics: analytics,
            hasCompletedJourney: hasCompletedJourney
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Key.snapshot)
        }
    }
}
