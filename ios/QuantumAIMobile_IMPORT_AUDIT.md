# QuantumAIMobile Import Audit

Date: 2026-03-28
Repository root: `/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3`

## Scope snapshot

`git status --short -- ios/QuantumAIMobile` currently reports 90 untracked entries under the Swift package tree.

Largest buckets:
- `ios/QuantumAIMobile/QuantumAIMobile/AppShell`: 37 entries
- `ios/QuantumAIMobile/QuantumAIMobile/CoreKit`: 25 entries
- package/build scaffolding and module directories: remaining 28 entries

Already tracked under `ios/QuantumAIMobile`:
- shell migration files such as `AppEnvironment.swift`, `PanelView.swift`, `SettingsView.swift`, `TrainingJourneyView.swift`
- design-system files under `DesignSystem/`
- a narrow `CoreKit` subset: `TrainingBundleResource.swift`, `TrainingGuideStore.swift`

This means the untracked tree is not a clean standalone drop. It overlaps the active tracked package and must be imported in bounded slices.

## Immediate decision

1. Ignore local SwiftPM build artifacts now.
2. Do not bulk-add the untracked source tree.
3. Prepare the source import as separate commit buckets with overlap review.

## Targeted ignore rules

These paths are local-only and should not enter history:
- `ios/QuantumAIMobile/.build/`
- `ios/QuantumAIMobile/.swiftpm/`

If later discovered, also keep these local-only:
- `ios/QuantumAIMobile/**/xcuserdata/`
- `ios/QuantumAIMobile/**/.DS_Store`

## Proposed import commit set

### Commit A — Package scaffolding
Safe to review first because it defines package boundaries without changing runtime behavior.

Include:
- `ios/QuantumAIMobile/Package.swift`
- `ios/QuantumAIMobile/project.yml`
- `ios/QuantumAIMobile/README_IOS_MEGA_BORU_HATTI.md`
- `ios/QuantumAIMobile/Docs/`
- `ios/QuantumAIMobile/ci_scripts/`

Gate:
- no host-project user data
- no generated SwiftPM output

### Commit B — Non-UI module sources
Bring in underlying engines before more screens depend on them.

Candidate directories:
- `ios/QuantumAIMobile/QuantumAIMobile/AlertKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/BotKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/MarketKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/NetworkKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/ObservabilityKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/PropertyKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/Resources/`
- `ios/QuantumAIMobile/QuantumAIMobile/Runbook/`
- `ios/QuantumAIMobile/QuantumAIMobile/SecurityKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/SettingsKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/StorageKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/Support/`
- `ios/QuantumAIMobile/QuantumAIMobile/SyncKit/`
- `ios/QuantumAIMobile/QuantumAIMobile/WalletKit/`

Gate:
- review symbol collisions against already tracked `AppEnvironment.swift`, `TrainingGuideStore.swift`, and shell-connected types
- do not import `CoreKit` in the same commit

### Commit C — CoreKit overlap import
This is the highest-risk bucket because `CoreKit` already has tracked files and shared runtime types.

Candidate files include:
- `ios/QuantumAIMobile/QuantumAIMobile/CoreKit/RuntimeMetricsRegistry.swift`
- `ios/QuantumAIMobile/QuantumAIMobile/CoreKit/TrainingJourneyStore.swift`
- `ios/QuantumAIMobile/QuantumAIMobile/CoreKit/NeuralCrownEntegrator.swift`
- remaining untracked `CoreKit/*.swift`

Gate:
- inspect for duplicate type names and dependency direction into tracked shell/design-system files
- import in reviewed subsets, not as a single blanket add

### Commit D — UI expansion and host harness
Leave UI-heavy and host-project files for the last import step.

Candidate paths:
- untracked `ios/QuantumAIMobile/QuantumAIMobile/AppShell/*.swift`
- `ios/QuantumAIMobile/QuantumAIMobileAppHost/`
- `ios/QuantumAIMobile/QuantumAIMobileHost.xcodeproj/`
- `ios/QuantumAIMobile/QuantumAIMobileTests/*.swift`

Gate:
- review screen ownership against the already migrated shell
- exclude any local Xcode user data
- run package tests after each slice

## Recommended next execution order

1. land ignore rules for SwiftPM local artifacts
2. import Commit A scaffolding only
3. audit module directories for collisions and land Commit B
4. split `CoreKit` import into reviewed subsets
5. import remaining UI/host/test files last
