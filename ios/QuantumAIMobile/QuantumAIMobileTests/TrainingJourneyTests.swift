import XCTest
@testable import QuantumAIMobile

@MainActor
final class TrainingJourneyTests: XCTestCase {
    func testJourneyBlocksUntilPrerequisitesAndQuizAreComplete() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sut = TrainingJourneyStore(defaults: defaults)

        sut.currentStep = .prerequisites
        XCTAssertFalse(sut.canAdvance)

        var prerequisites = sut.prerequisites
        prerequisites.notificationsReady = true
        prerequisites.accountReady = true
        prerequisites.networkReady = true
        prerequisites.deviceReady = true
        prerequisites.securityVerified = true
        sut.prerequisites = prerequisites
        XCTAssertTrue(sut.canAdvance)

        sut.currentStep = .quiz
        XCTAssertFalse(sut.canAdvance)

        for question in TrainingJourneyStore.quizQuestions {
            sut.answer(questionID: question.id, optionIndex: question.correctIndex)
        }

        XCTAssertTrue(sut.canAdvance)
        XCTAssertEqual(sut.quizScore, TrainingJourneyStore.quizQuestions.count)
    }

    func testJourneyPersistsProgressAndCompletionSnapshot() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sut = TrainingJourneyStore(defaults: defaults)
        sut.currentStep = .completion
        sut.selectedRole = .executive
        sut.selectedLevel = .advanced
        sut.selectedMode = .deepDive
        sut.toggleModule(.walletActivation)
        sut.runSandboxTrade(label: "Sandbox BUY")
        sut.submitFeedback(score: 4)
        sut.completeJourney()

        let restored = TrainingJourneyStore(defaults: defaults)
        XCTAssertEqual(restored.currentStep, .completion)
        XCTAssertEqual(restored.selectedRole, .executive)
        XCTAssertEqual(restored.selectedLevel, .advanced)
        XCTAssertEqual(restored.selectedMode, .deepDive)
        XCTAssertTrue(restored.selectedModules.contains(.walletActivation))
        XCTAssertEqual(restored.sandbox.completedTrades, 1)
        XCTAssertEqual(restored.analytics.feedbackScore, 4)
        XCTAssertTrue(restored.hasCompletedJourney)
    }

    func testWalletActivationStoreTracksVerificationLifecycle() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sut = WalletActivationStore(defaults: defaults)

        XCTAssertEqual(sut.status(for: .metamask), .idle)
        sut.markActivationStarted(for: .metamask)
        XCTAssertEqual(sut.status(for: .metamask), .activationStarted)

        sut.markVerified(for: .metamask)
        XCTAssertEqual(sut.status(for: .metamask), .verified)
        XCTAssertNotNil(sut.verifiedAt(for: .metamask))
        XCTAssertEqual(sut.verifiedProviders, [.metamask])

        sut.reset(.metamask)
        XCTAssertEqual(sut.status(for: .metamask), .idle)
        XCTAssertNil(sut.verifiedAt(for: .metamask))
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "TrainingJourneyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
