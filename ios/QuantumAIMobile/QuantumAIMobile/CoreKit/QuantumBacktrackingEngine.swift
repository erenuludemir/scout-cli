import Foundation

public struct Complex: Equatable, Sendable {
    public var real: Double
    public var imag: Double

    public init(r: Double, i: Double) {
        self.real = r
        self.imag = i
    }

    public static let zero = Complex(r: 0, i: 0)
    public static let one = Complex(r: 1, i: 0)

    public var magnitudeSquared: Double {
        (real * real) + (imag * imag)
    }

    public func scaled(by factor: Double) -> Complex {
        Complex(r: real * factor, i: imag * factor)
    }

    public func reflected() -> Complex {
        Complex(r: -real, i: -imag)
    }
}

public protocol QuantumVariable: Sendable {
    var id: UUID { get }
}

public struct QuantumBool: QuantumVariable, Equatable, Sendable {
    public let id: UUID
    public var state: Bool

    public init(id: UUID = UUID(), state: Bool) {
        self.id = id
        self.state = state
    }
}

public struct QuantumArray: QuantumVariable, Equatable, Sendable {
    public let id: UUID
    public var size: Int

    public init(id: UUID = UUID(), size: Int) {
        self.id = id
        self.size = max(1, size)
    }
}

public struct QuantumNode: Hashable, Sendable {
    public let path: [Int]

    public init(path: [Int]) {
        self.path = path
    }

    public var depth: Int { path.count }
}

public enum QuantumReflectionOperator: String, Equatable, Sendable {
    case rA = "R_A"
    case rB = "R_B"
}

public struct QuantumBacktrackingEvaluation: Equatable, Sendable {
    public let solutionPath: [Int]?
    public let evaluatedNodes: Int
    public let acceptedNodes: Int
    public let rejectedNodes: Int
    public let estimatedPhase: Double
    public let activeOperators: [QuantumReflectionOperator]
    public let symbolicComplexity: String
    public let workEstimate: Double
    public let graphSummary: String

    public static let idle = QuantumBacktrackingEvaluation(
        solutionPath: nil,
        evaluatedNodes: 0,
        acceptedNodes: 0,
        rejectedNodes: 0,
        estimatedPhase: 0,
        activeOperators: [],
        symbolicComplexity: "O(sqrt(T) n^(3/2) log n)",
        workEstimate: 0,
        graphSummary: "Graph(Nodes: 0, Edges: 0)"
    )
}

public enum QuantumProjectPriorityLevel: Int, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: QuantumProjectPriorityLevel, rhs: QuantumProjectPriorityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct QuantumProjectPriority: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let level: QuantumProjectPriorityLevel
    public let route: String

    public init(id: String, title: String, detail: String, level: QuantumProjectPriorityLevel, route: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.level = level
        self.route = route
    }
}

public struct QuantumHierarchySnapshot: Equatable, Sendable {
    public let headline: String
    public let dispatchMode: String
    public let priorities: [QuantumProjectPriority]

    public static let idle = QuantumHierarchySnapshot(
        headline: "Quantum hierarchy idle",
        dispatchMode: "Awaiting workload",
        priorities: []
    )
}

public struct QuantumWorkloadMetrics: Equatable, Sendable {
    public struct Signature: Equatable, Sendable {
        public let latencyBucket: Int
        public let noiseBucket: Int
        public let qkdStatus: String
        public let isAIOptimized: Bool
        public let retainedLogBucket: Int
        public let branchFactor: Int
        public let searchDepth: Int
        public let precision: Int
    }

    public let averageLatency: Double
    public let averageNoise: Double
    public let qkdStatus: String
    public let isAIOptimized: Bool
    public let retainedLogCount: Int
    public let branchFactor: Int
    public let searchDepth: Int
    public let precision: Int

    public init(
        averageLatency: Double,
        averageNoise: Double,
        qkdStatus: String,
        isAIOptimized: Bool,
        retainedLogCount: Int,
        branchFactor: Int,
        searchDepth: Int,
        precision: Int
    ) {
        self.averageLatency = averageLatency
        self.averageNoise = averageNoise
        self.qkdStatus = qkdStatus
        self.isAIOptimized = isAIOptimized
        self.retainedLogCount = retainedLogCount
        self.branchFactor = max(2, branchFactor)
        self.searchDepth = max(1, searchDepth)
        self.precision = max(1, precision)
    }

    public var signature: Signature {
        Signature(
            latencyBucket: Int((averageLatency / 5).rounded()),
            noiseBucket: Int((averageNoise / 5).rounded()),
            qkdStatus: qkdStatus,
            isAIOptimized: isAIOptimized,
            retainedLogBucket: retainedLogCount / 4,
            branchFactor: branchFactor,
            searchDepth: searchDepth,
            precision: precision
        )
    }
}

public struct QuantumOptimizationPlan: Equatable, Sendable {
    public let evaluation: QuantumBacktrackingEvaluation
    public let hierarchy: QuantumHierarchySnapshot
}

public actor QuantumBacktrackingTree {
    public typealias Predicate = @Sendable (QuantumNode) -> QuantumBool

    public let maxDepth: Int
    public let branchQA: QuantumArray
    public let accept: Predicate
    public let reject: Predicate

    private var internalStatevector: [QuantumNode: Complex] = [:]
    private var lastEvaluation: QuantumBacktrackingEvaluation = .idle
    private var lastEstimatedPhase: Double = 0
    private var operatorHistory: [QuantumReflectionOperator] = []

    public init(
        maxDepth: Int,
        branchQA: QuantumArray,
        accept: @escaping Predicate,
        reject: @escaping Predicate
    ) {
        self.maxDepth = max(0, maxDepth)
        self.branchQA = branchQA
        self.accept = accept
        self.reject = reject
    }

    public func qstepDiffuser(isA: Bool) {
        if internalStatevector.isEmpty {
            internalStatevector[QuantumNode(path: [])] = .one
        }

        let partitionNodes = internalStatevector.keys.filter { matchesPartition($0, isA: isA) }
        guard !partitionNodes.isEmpty else { return }

        let normalization = 1.0 / sqrt(Double(partitionNodes.count))
        for node in partitionNodes {
            if reject(node).state {
                internalStatevector[node] = .zero
                continue
            }

            let current = internalStatevector[node] ?? .one
            let adjusted = accept(node).state ? current.scaled(by: normalization) : current.reflected().scaled(by: normalization)
            internalStatevector[node] = adjusted
        }

        operatorHistory.append(isA ? .rA : .rB)
    }

    public func quantumStep(controls: [QuantumBool] = []) {
        guard controls.allSatisfy(\.state) else { return }
        qstepDiffuser(isA: true)
        qstepDiffuser(isA: false)
    }

    public func estimatePhase(precision: Int) -> Double {
        let accepted = internalStatevector.keys.filter { accept($0).state }.count
        let total = max(internalStatevector.count, 1)
        let base = accepted > 0 ? Double(accepted) / Double(total) : 1.0 / Double(max(maxDepth, 1) + 1)
        let phase = min(1.0, max(0.0, base * Double(max(1, precision)))) * .pi
        lastEstimatedPhase = phase.rounded(toPlaces: 4)
        return lastEstimatedPhase
    }

    public func findSolution(precision: Int) -> [Int]? {
        if internalStatevector.isEmpty {
            initNode(path: [])
        }

        var queue: [QuantumNode] = [QuantumNode(path: [])]
        var cursor = 0
        var visited = Set<QuantumNode>()
        var evaluatedNodes = 0
        var acceptedNodes = 0
        var rejectedNodes = 0
        var solution: [Int]?

        while cursor < queue.count {
            let node = queue[cursor]
            cursor += 1

            guard visited.insert(node).inserted else { continue }
            evaluatedNodes += 1

            if reject(node).state {
                rejectedNodes += 1
                internalStatevector[node] = .zero
                continue
            }

            if accept(node).state {
                acceptedNodes += 1
                internalStatevector[node] = .one
                solution = node.path
                break
            }

            guard node.depth < maxDepth else { continue }

            let children = (0 ..< branchQA.size)
                .map { QuantumNode(path: node.path + [$0]) }
                .sorted(by: preferredBranchOrder)

            let amplitude = 1.0 / sqrt(Double(max(children.count, 1)))
            for child in children where internalStatevector[child] == nil {
                internalStatevector[child] = Complex(r: amplitude, i: 0)
            }
            queue.append(contentsOf: children)
        }

        let treeSize = max(internalStatevector.count, evaluatedNodes, 1)
        let complexity = sqrt(Double(treeSize)) * pow(Double(max(maxDepth, 1)), 1.5) * log2(Double(max(maxDepth, 2)))

        lastEvaluation = QuantumBacktrackingEvaluation(
            solutionPath: solution,
            evaluatedNodes: evaluatedNodes,
            acceptedNodes: acceptedNodes,
            rejectedNodes: rejectedNodes,
            estimatedPhase: estimatePhase(precision: precision),
            activeOperators: Array(operatorHistory.suffix(4)),
            symbolicComplexity: "O(sqrt(T) n^(3/2) log n)",
            workEstimate: complexity,
            graphSummary: statevectorGraph()
        )

        return solution
    }

    public func initPhi(path: [Int]) {
        let node = QuantumNode(path: path)
        let children = node.depth < maxDepth
            ? (0 ..< branchQA.size).map { QuantumNode(path: path + [$0]) }
            : []
        let basis = [node] + children
        let amplitude = 1.0 / sqrt(Double(max(basis.count, 1)))

        internalStatevector.removeAll(keepingCapacity: true)
        for basisNode in basis {
            internalStatevector[basisNode] = Complex(r: amplitude, i: 0)
        }
    }

    public func initNode(path: [Int]) {
        internalStatevector[QuantumNode(path: path)] = .one
    }

    public func statevector() -> [QuantumNode: Complex] {
        internalStatevector
    }

    public func visualizeStatevector() -> [String] {
        internalStatevector
            .sorted { $0.key.path.lexicographicallyPrecedes($1.key.path) }
            .map { node, amplitude in
                "Node \(node.path) -> Amplitude: \(amplitude.real) + \(amplitude.imag)i"
            }
    }

    public func statevectorGraph() -> String {
        let edgeCount = internalStatevector.keys.reduce(into: 0) { partial, node in
            partial += min(max(maxDepth - node.depth, 0), branchQA.size)
        }
        return "Graph(Nodes: \(internalStatevector.keys.count), Edges: \(edgeCount))"
    }

    public func subtree(newRoot: QuantumNode) async -> QuantumBacktrackingTree {
        let accept = self.accept
        let reject = self.reject
        let rootPath = newRoot.path
        let subtree = QuantumBacktrackingTree(
            maxDepth: max(0, maxDepth - newRoot.depth),
            branchQA: branchQA,
            accept: { node in accept(QuantumNode(path: rootPath + node.path)) },
            reject: { node in reject(QuantumNode(path: rootPath + node.path)) }
        )
        await subtree.initPhi(path: [])
        return subtree
    }

    public func copy() async -> QuantumBacktrackingTree {
        let accept = self.accept
        let reject = self.reject
        let clone = QuantumBacktrackingTree(maxDepth: maxDepth, branchQA: branchQA, accept: accept, reject: reject)
        await clone.restore(
            statevector: internalStatevector,
            lastEvaluation: lastEvaluation,
            lastEstimatedPhase: lastEstimatedPhase,
            operatorHistory: operatorHistory
        )
        return clone
    }

    public func pathDecoder(h: Int, branchQA: QuantumArray) -> [Int] {
        let cappedHeight = max(0, h)
        let strongestNode = internalStatevector.max { lhs, rhs in
            lhs.value.magnitudeSquared < rhs.value.magnitudeSquared
        }?.key.path ?? []

        if strongestNode.count >= cappedHeight {
            return Array(strongestNode.prefix(cappedHeight))
        }

        let fallbackTail = Array(repeating: 0, count: max(0, cappedHeight - strongestNode.count))
        return Array(strongestNode.prefix(cappedHeight)) + fallbackTail.map { $0 % max(branchQA.size, 1) }
    }

    public func evaluation() -> QuantumBacktrackingEvaluation {
        lastEvaluation
    }

    private func restore(
        statevector: [QuantumNode: Complex],
        lastEvaluation: QuantumBacktrackingEvaluation,
        lastEstimatedPhase: Double,
        operatorHistory: [QuantumReflectionOperator]
    ) {
        internalStatevector = statevector
        self.lastEvaluation = lastEvaluation
        self.lastEstimatedPhase = lastEstimatedPhase
        self.operatorHistory = operatorHistory
    }

    private func matchesPartition(_ node: QuantumNode, isA: Bool) -> Bool {
        node.depth.isMultiple(of: 2) == isA
    }

    private func preferredBranchOrder(lhs: QuantumNode, rhs: QuantumNode) -> Bool {
        let lhsScore = heuristicScore(for: lhs)
        let rhsScore = heuristicScore(for: rhs)
        if lhsScore == rhsScore {
            return lhs.path.lexicographicallyPrecedes(rhs.path)
        }
        return lhsScore > rhsScore
    }

    private func heuristicScore(for node: QuantumNode) -> Int {
        let branchBias = node.path.reduce(0, +)
        let acceptBias = accept(node).state ? 100 : 0
        let rejectPenalty = reject(node).state ? 100 : 0
        return (node.depth * 10) + branchBias + acceptBias - rejectPenalty
    }
}

public actor QuantumBacktrackingPlanner {
    public init() {}

    public func optimize(workload: QuantumWorkloadMetrics) async -> QuantumOptimizationPlan {
        let branchArray = QuantumArray(size: workload.branchFactor)
        let targetPath = targetPath(for: workload, branchFactor: branchArray.size)
        let maxDepth = workload.searchDepth

        let tree = QuantumBacktrackingTree(
            maxDepth: maxDepth,
            branchQA: branchArray,
            accept: { node in
                QuantumBool(state: node.path == targetPath)
            },
            reject: { node in
                if node.depth > maxDepth {
                    return QuantumBool(state: true)
                }
                if workload.qkdStatus == "COMPROMISED", node.path.contains(branchArray.size - 1) {
                    return QuantumBool(state: true)
                }
                if workload.averageNoise > 70, node.path.suffix(2).count == 2 {
                    let tail = Array(node.path.suffix(2))
                    return QuantumBool(state: Set(tail).count == 1)
                }
                return QuantumBool(state: false)
            }
        )

        await tree.initPhi(path: [])
        await tree.quantumStep(controls: [QuantumBool(state: true)])
        _ = await tree.findSolution(precision: workload.precision)
        let evaluation = await tree.evaluation()
        let hierarchy = buildHierarchy(for: workload, evaluation: evaluation)
        return QuantumOptimizationPlan(evaluation: evaluation, hierarchy: hierarchy)
    }

    private func buildHierarchy(
        for workload: QuantumWorkloadMetrics,
        evaluation: QuantumBacktrackingEvaluation
    ) -> QuantumHierarchySnapshot {
        var priorities: [QuantumProjectPriority] = []

        if workload.qkdStatus == "COMPROMISED" {
            priorities.append(
                QuantumProjectPriority(
                    id: "qkd-rotate",
                    title: "QKD kanalini yeniden anahtarla",
                    detail: "Kompromize hat bulundu. Rota: Security -> Quantum Ops -> Re-key.",
                    level: .critical,
                    route: "Security/Quantum Ops"
                )
            )
        }

        if workload.averageNoise > 55 {
            priorities.append(
                QuantumProjectPriority(
                    id: "noise-stabilize",
                    title: "NISQ gurultusunu dusur",
                    detail: "Gurultu bucketi kritik. Terminal feed ve PQC parametreleri yeniden dengelenmeli.",
                    level: workload.averageNoise > 75 ? .critical : .high,
                    route: "Quantum Ops/Terminal"
                )
            )
        }

        if workload.averageLatency > 60 {
            priorities.append(
                QuantumProjectPriority(
                    id: "latency-rebalance",
                    title: "PQC gecikmesini yeniden dengele",
                    detail: "Backtracking plani, dusuk latency patikasini onceliklendirdi.",
                    level: workload.averageLatency > 120 ? .high : .medium,
                    route: "Market Bridge/PQC"
                )
            )
        }

        if !workload.isAIOptimized {
            priorities.append(
                QuantumProjectPriority(
                    id: "enable-ai",
                    title: "AI optimizasyonunu aktif et",
                    detail: "Neural pathfinder kapali. Quantum walk daha pahali calisiyor.",
                    level: .medium,
                    route: "Quantum Ops/Control"
                )
            )
        }

        priorities.append(
            QuantumProjectPriority(
                id: "route-solution",
                title: "Bulunan patikayi operasyona aktar",
                detail: solutionText(for: evaluation.solutionPath),
                level: evaluation.solutionPath == nil ? .medium : .low,
                route: "HQ Admin/Command"
            )
        )

        let ordered = priorities.sorted { lhs, rhs in
            if lhs.level == rhs.level {
                return lhs.title < rhs.title
            }
            return lhs.level > rhs.level
        }

        let headline: String
        if let first = ordered.first {
            headline = first.level == .critical
                ? "Hierarchy escalated: critical path first"
                : "Hierarchy balanced around live workload"
        } else {
            headline = "Hierarchy stable"
        }

        let dispatchMode = workload.isAIOptimized
            ? "Quantum walk + async utility dispatch"
            : "Classical fallback + kernel-driven telemetry"

        return QuantumHierarchySnapshot(
            headline: headline,
            dispatchMode: dispatchMode,
            priorities: Array(ordered.prefix(4))
        )
    }

    private func targetPath(for workload: QuantumWorkloadMetrics, branchFactor: Int) -> [Int] {
        let seed = abs(Int(workload.averageLatency.rounded()))
            ^ (abs(Int(workload.averageNoise.rounded())) << 1)
            ^ (workload.isAIOptimized ? 7 : 3)
            ^ workload.qkdStatus.hashValue

        return (0 ..< workload.searchDepth).map { index in
            abs(seed + (index * 17)) % max(branchFactor, 1)
        }
    }

    private func solutionText(for path: [Int]?) -> String {
        guard let path, !path.isEmpty else {
            return "Kuantum yurumede kesin bir yol henuz olusmadi. Kritik backlog korunuyor."
        }
        return "Secilen yurutme yolu: \(path.map(String.init).joined(separator: " -> "))."
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
