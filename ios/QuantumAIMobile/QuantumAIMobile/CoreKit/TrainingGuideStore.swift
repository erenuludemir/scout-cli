import Foundation
import Combine
import OSLog

public enum TrainingCategory: String, CaseIterable, Identifiable, Sendable {
    case overview
    case architecture
    case strategy
    case automation
    case operations
    case security
    case api
    case deployment
    case support

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview:
            return "Genel Bakış"
        case .architecture:
            return "Mimari"
        case .strategy:
            return "Strateji"
        case .automation:
            return "Otomasyon"
        case .operations:
            return "Operasyon"
        case .security:
            return "Güvenlik"
        case .api:
            return "API"
        case .deployment:
            return "Dağıtım"
        case .support:
            return "Destek"
        }
    }
}

public struct TrainingSection: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let highlights: [String]
    public let category: TrainingCategory
    public let codeBlockCount: Int
    public let diagramCount: Int
}

public struct StrategyPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let sourceSectionID: String
    public let dcaAmount: Double
    public let dcaPeriodSec: Int
    public let gridBandLowerRatio: Double
    public let gridBandUpperRatio: Double
    public let gridSteps: Int
    public let copyRatio: Double
    public let shockThreshold: Double
    public let prefersSimulation: Bool
    public let preferredSymbol: String?
    public let requiresLicense: Bool
}

public struct TrainingRecommendation: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let category: TrainingCategory
    public let sourceSectionID: String
}

public struct BrainContext: Sendable {
    public let queueDepth: Int
    public let retryRate: Double
    public let estimatedPnL: Double
    public let activeOrders: Int
    public let usesSimulation: Bool
    public let isAuthenticated: Bool
    public let selectedSymbol: String
    public let isCopyTradeActive: Bool

    public init(queueDepth: Int, retryRate: Double, estimatedPnL: Double, activeOrders: Int, usesSimulation: Bool, isAuthenticated: Bool, selectedSymbol: String, isCopyTradeActive: Bool) {
        self.queueDepth = queueDepth
        self.retryRate = retryRate
        self.estimatedPnL = estimatedPnL
        self.activeOrders = activeOrders
        self.usesSimulation = usesSimulation
        self.isAuthenticated = isAuthenticated
        self.selectedSymbol = selectedSymbol
        self.isCopyTradeActive = isCopyTradeActive
    }
}

public struct TrainingGuide: Sendable {
    public let title: String
    public let summary: String
    public let sections: [TrainingSection]
    public let presets: [StrategyPreset]

    static let empty = TrainingGuide(title: "QuantumAI Rehberi", summary: "Kaynak bekleniyor", sections: [], presets: [])
}

public final class TrainingGuideStore: ObservableObject {
    @Published public private(set) var guide: TrainingGuide = .empty
    @Published public private(set) var isLoading = false
    private var hasLoaded = false
    private var loadTask: Task<Void, Never>?
    private static var cachedGuide: TrainingGuide?

    public init() {}

    public func loadIfNeeded(synchronously: Bool = false, priority: TaskPriority = .utility) {
        guard !hasLoaded || guide.sections.isEmpty else { return }
        if let cachedGuide = Self.cachedGuide {
            apply(cachedGuide)
            return
        }

        if synchronously {
            guard let parsedGuide = Self.loadGuideSynchronously() else { return }
            apply(parsedGuide)
            return
        }

        guard loadTask == nil else { return }
        isLoading = true
        loadTask = Task(priority: priority) { [weak self] in
            let parsedGuide = await Self.loadGuideInBackground(priority: priority)
            guard let store = self else { return }
            await MainActor.run {
                store.loadTask = nil
                store.isLoading = false
                guard let parsedGuide else { return }
                store.apply(parsedGuide)
            }
        }
    }

    private func apply(_ parsedGuide: TrainingGuide) {
        guide = parsedGuide
        hasLoaded = true
        Self.cachedGuide = parsedGuide

        if #available(iOS 15.0, macOS 12.0, *) {
            QAISignpost.event(
                "Training Ready",
                message: "sections=\(parsedGuide.sections.count) presets=\(parsedGuide.presets.count)"
            )
        }
    }

    private static func loadGuideInBackground(priority: TaskPriority) async -> TrainingGuide? {
        await Task.detached(priority: priority) {
            loadGuideSynchronously()
        }.value
    }

    private static func loadGuideSynchronously() -> TrainingGuide? {
        let interval: Any? = {
            if #available(iOS 15.0, macOS 12.0, *) {
                return QAISignpost.begin("Training Load")
            }
            return nil
        }()
        defer {
            if #available(iOS 15.0, macOS 12.0, *), let interval = interval as? OSSignpostIntervalState {
                QAISignpost.end("Training Load", interval)
            }
        }

        guard
            let url = ResourceBundle.url(forResource: "TrainingV140721", withExtension: "html", subdirectory: "Training"),
            let html = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }

        let title = Self.firstMatch(in: html, pattern: #"<title>(.*?)</title>"#) ?? "QuantumAI Eğitim Rehberi"
        let summary = Self.firstMatch(in: html, pattern: #"<meta name="description" content="(.*?)">"#) ?? "Eğitim kaynağı yüklendi."
        let sections = Self.extractSections(from: html)
        return TrainingGuide(
            title: Self.decodeEntities(title),
            summary: Self.decodeEntities(summary),
            sections: sections,
            presets: Self.buildPresets(from: sections)
        )
    }

    public func sections(for category: TrainingCategory) -> [TrainingSection] {
        guide.sections.filter { $0.category == category }
    }

    public func section(withID id: String) -> TrainingSection? {
        guide.sections.first { $0.id == id }
    }

    public func primaryRecommendation(for context: BrainContext) -> TrainingRecommendation? {
        contextualRecommendations(for: context).first
    }

    public func contextualRecommendations(for context: BrainContext) -> [TrainingRecommendation] {
        guard !guide.sections.isEmpty else { return [] }
        var recommendations: [TrainingRecommendation] = []

        if !context.isAuthenticated {
            recommendations.append(recommendation(
                id: "license-activation",
                title: "Lisans aktivasyonunu tamamla",
                summary: "Quantum bot suite ve gelişmiş otomasyon akışları için lisans merkezi üzerinden TRC20 aktivasyonunu kalıcı hale getir.",
                fallbackSectionID: "quantum-bot-suite",
                category: .strategy
            ))
        }

        if context.retryRate >= 0.2 || context.queueDepth >= 4 {
            recommendations.append(recommendation(
                id: "ops-recovery",
                title: "Outbox ve retry hattını stabilize et",
                summary: "Operasyon ve continuity bölümlerindeki failover, DLQ ve kuyruk yönetimi adımlarını uygula. Yüksek retry oranında yeni emir üretimini sınırlı tut.",
                fallbackSectionID: "operations",
                category: .operations
            ))
        }

        if context.estimatedPnL < 0 {
            recommendations.append(recommendation(
                id: "risk-guard",
                title: "Risk koruma profilini uygula",
                summary: "Negatif PnL ortamında şok eşiğini sıkılaştır, daha küçük DCA ve dar grid bandı kullan.",
                fallbackSectionID: "core-components",
                category: .strategy
            ))
        }

        if context.usesSimulation {
            recommendations.append(recommendation(
                id: "simulation-readiness",
                title: "Simülasyon üzerinden strateji doğrula",
                summary: "Canlıya geçmeden önce development ve automation bölümlerindeki test akışlarını kullanarak presetleri doğrula.",
                fallbackSectionID: "development",
                category: .automation
            ))
        } else {
            recommendations.append(recommendation(
                id: "live-execution",
                title: "\(context.selectedSymbol) için canlı operasyon",
                summary: "Canlı adapter modunda deployment ve observability bölümlerindeki sağlık kontrollerini izleyerek pozisyon büyüklüğünü yönet.",
                fallbackSectionID: "deployment",
                category: .deployment
            ))
        }

        if context.isCopyTradeActive {
            recommendations.append(recommendation(
                id: "copytrade-followup",
                title: "CopyTrade sync disiplinini koru",
                summary: "Copy trade çalışırken API ve observability bölümlerindeki order latency ile senkron kontrollerini takip et.",
                fallbackSectionID: "api-reference",
                category: .api
            ))
        }

        if recommendations.isEmpty {
            recommendations.append(recommendation(
                id: "strategy-expand",
                title: "Strateji kütüphanesinden preset uygula",
                summary: "Quantum bot suite ve mega pipeline bölümlerinden türetilen hazır yönetim stratejilerini devreye al.",
                fallbackSectionID: "mega-master-pipeline",
                category: .strategy
            ))
        }

        return recommendations
    }

    private func recommendation(id: String, title: String, summary: String, fallbackSectionID: String, category: TrainingCategory) -> TrainingRecommendation {
        let section = section(withID: fallbackSectionID)
            ?? guide.sections.first(where: { $0.category == category })
            ?? guide.sections.first
        return TrainingRecommendation(
            id: id,
            title: title,
            summary: summary,
            category: category,
            sourceSectionID: section?.id ?? fallbackSectionID
        )
    }

    private static func extractSections(from html: String) -> [TrainingSection] {
        let pattern = #"<section id="([^"]+)" class="panel">(.*?)</section>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
        let nsrange = NSRange(html.startIndex..., in: html)
        let sectionMatches = regex?.matches(in: html, options: [], range: nsrange) ?? []

        var seen = Set<String>()
        var sections: [TrainingSection] = []

        for match in sectionMatches {
            guard
                let idRange = Range(match.range(at: 1), in: html),
                let bodyRange = Range(match.range(at: 2), in: html)
            else { continue }

            let id = String(html[idRange])
            guard !seen.contains(id), id != "raw-appendix" else { continue }
            seen.insert(id)

            let body = String(html[bodyRange])
            let title = firstMatch(in: body, pattern: #"<h2>(.*?)</h2>"#) ?? id
            let paragraphs = self.matches(in: body, pattern: #"<p>(.*?)</p>"#).map { decodeEntities(stripTags($0)).trimmingCharacters(in: .whitespacesAndNewlines) }
            let summary = paragraphs.first(where: { !$0.isEmpty }) ?? "Detaylar eğitim rehberinde mevcut."
            let highlights = self.matches(in: body, pattern: #"<li>(.*?)</li>"#)
                .map { decodeEntities(stripTags($0)).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(4)
                .map { $0 }
            let codeBlockCount = countMatches(in: body, pattern: #"<pre"#)
            let diagramCount = body.components(separatedBy: "mermaid").count - 1

            sections.append(
                TrainingSection(
                    id: id,
                    title: decodeEntities(stripTags(title)),
                    summary: summary,
                    highlights: Array(highlights),
                    category: category(for: id, title: title),
                    codeBlockCount: codeBlockCount,
                    diagramCount: max(diagramCount, 0)
                )
            )
        }

        return sections
    }

    private static func buildPresets(from sections: [TrainingSection]) -> [StrategyPreset] {
        func sectionID(preferredIDs: [String], category: TrainingCategory) -> String {
            for preferredID in preferredIDs {
                if let match = sections.first(where: { $0.id == preferredID }) {
                    return match.id
                }
            }

            if let categoryMatch = sections.first(where: { $0.category == category }) {
                return categoryMatch.id
            }

            return sections.first?.id ?? preferredIDs.first ?? "system-overview"
        }

        return [
            StrategyPreset(
                id: "precision-dca",
                title: "Precision DCA",
                summary: "Kontrollü giriş, daha düşük şok eşiği ve demo odaklı güvenli başlangıç.",
                sourceSectionID: sectionID(preferredIDs: ["quantum-bot-suite", "core-components", "system-overview"], category: .strategy),
                dcaAmount: 25,
                dcaPeriodSec: 45,
                gridBandLowerRatio: 0.025,
                gridBandUpperRatio: 0.03,
                gridSteps: 4,
                copyRatio: 0.70,
                shockThreshold: 0.010,
                prefersSimulation: true,
                preferredSymbol: "BTCUSDT",
                requiresLicense: false
            ),
            StrategyPreset(
                id: "momentum-grid",
                title: "Momentum Grid",
                summary: "Canlı adapter için geniş bantlı grid ve orta agresif pozisyon yönetimi.",
                sourceSectionID: sectionID(preferredIDs: ["mega-master-pipeline", "quantum-bot-suite", "core-components", "system-overview"], category: .strategy),
                dcaAmount: 45,
                dcaPeriodSec: 30,
                gridBandLowerRatio: 0.05,
                gridBandUpperRatio: 0.06,
                gridSteps: 7,
                copyRatio: 0.85,
                shockThreshold: 0.015,
                prefersSimulation: false,
                preferredSymbol: "ETHUSDT",
                requiresLicense: true
            ),
            StrategyPreset(
                id: "recovery-shield",
                title: "Recovery Shield",
                summary: "Retry ve queue baskısında yükü azaltan operasyon kurtarma profili.",
                sourceSectionID: sectionID(preferredIDs: ["operations", "support", "system-overview"], category: .operations),
                dcaAmount: 15,
                dcaPeriodSec: 90,
                gridBandLowerRatio: 0.02,
                gridBandUpperRatio: 0.025,
                gridSteps: 3,
                copyRatio: 0.35,
                shockThreshold: 0.008,
                prefersSimulation: true,
                preferredSymbol: "BTCUSDT",
                requiresLicense: false
            ),
            StrategyPreset(
                id: "copy-surge",
                title: "Copy Surge",
                summary: "Aktif copy-trade ve yüksek frekanslı senkron akışı için premium preset.",
                sourceSectionID: sectionID(preferredIDs: ["api-reference", "operations", "support", "system-overview"], category: .api),
                dcaAmount: 30,
                dcaPeriodSec: 20,
                gridBandLowerRatio: 0.035,
                gridBandUpperRatio: 0.045,
                gridSteps: 6,
                copyRatio: 1.25,
                shockThreshold: 0.018,
                prefersSimulation: false,
                preferredSymbol: "SOLUSDT",
                requiresLicense: true
            )
        ]
    }

    private static func category(for id: String, title: String) -> TrainingCategory {
        let key = "\(id) \(title)".lowercased()
        if key.contains("security") { return .security }
        if key.contains("deployment") || key.contains("configuration") { return .deployment }
        if key.contains("api") { return .api }
        if key.contains("automation") || key.contains("watcher") { return .automation }
        if key.contains("operation") || key.contains("continuity") || key.contains("observability") { return .operations }
        if key.contains("architecture") || key.contains("component") || key.contains("implementation") { return .architecture }
        if key.contains("bot") || key.contains("pipeline") || key.contains("risk") || key.contains("strategy") { return .strategy }
        if key.contains("support") { return .support }
        return .overview
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        matches(in: text, pattern: pattern).first
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
        let nsrange = NSRange(text.startIndex..., in: text)
        let matches = regex?.matches(in: text, options: [], range: nsrange) ?? []
        return matches.compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func countMatches(in text: String, pattern: String) -> Int {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsrange = NSRange(text.startIndex..., in: text)
        return regex?.numberOfMatches(in: text, options: [], range: nsrange) ?? 0
    }

    private static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#x2F;", with: "/")
    }

    deinit {
        loadTask?.cancel()
    }
}
