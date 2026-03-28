import SwiftUI
import Combine
#if canImport(Darwin)
import Darwin
#endif

public final class PQCFileWatcher: ObservableObject {
    @Published public private(set) var logLines: [String] = []

    public static var defaultLogFilePath: String {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("pqc_engine.log").path
    }

    public var entryPublisher: AnyPublisher<PQCLogEntry, Never> {
        entrySubject.eraseToAnyPublisher()
    }

    private let queue = DispatchQueue(label: "com.bursahq.filewatcher", qos: .background)
    private let entrySubject = PassthroughSubject<PQCLogEntry, Never>()
    private var fileHandle: FileHandle?
    private var monitorSource: DispatchSourceFileSystemObject?
    private var watchedPath: String?
    private var demoWriterTask: Task<Void, Never>?
    private let maxRetainedLines = 150

    public init() {}

    deinit {
        stopWatching()
    }

    public func startWatching(filePath: String) {
        guard watchedPath != filePath || monitorSource == nil else { return }
        stopWatching()

        let fileURL = URL(fileURLWithPath: filePath)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            appendLog("[SISTEM] Kritik Hata: Log dosyasina erisilemiyor -> \(filePath)")
            return
        }

        fileHandle = handle
        watchedPath = filePath
        handle.seekToEndOfFile()
        appendLog("[Bursa HQ] tail -f protokolu kernel seviyesinde baslatildi: \(filePath)")

        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor != -1 else {
            appendLog("[SISTEM] Dosya descriptor olusturulamadi -> \(filePath)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.readNewData()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        monitorSource = source
        source.resume()
    }

    public func stopWatching() {
        demoWriterTask?.cancel()
        demoWriterTask = nil
        monitorSource?.cancel()
        monitorSource = nil
        try? fileHandle?.close()
        fileHandle = nil
        watchedPath = nil
    }

    public func startDemoWriter(filePath: String) {
        demoWriterTask?.cancel()
        demoWriterTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1_200))
                guard let self else { return }

                let actions = ["Encapsulation", "Decapsulation", "KeyGen", "Signature Verify"]
                let protocols = ["Kyber-768", "Dilithium3", "Falcon-512"]
                let latency = String(format: "%.2f", Double.random(in: 8.0 ... 45.0))
                let noise = String(format: "%.1f", Double.random(in: 3.0 ... 18.0))
                let stamp = Date().formatted(date: .omitted, time: .standard)
                let line = "[\(stamp)] [\(protocols.randomElement() ?? "Kyber-768")] \(actions.randomElement() ?? "Encapsulation") tamamlandi. Gecikme: \(latency)ms Noise: \(noise)% AI AKTIF\n"

                await MainActor.run {
                    self.appendDemoLine(line, filePath: filePath)
                }
            }
        }
    }

    private func appendDemoLine(_ line: String, filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        if let data = line.data(using: .utf8) {
            try? handle.write(contentsOf: data)
        }
        try? handle.close()
    }

    private func readNewData() {
        guard let handle = fileHandle else { return }
        let data = handle.readDataToEndOfFile()
        guard let string = String(data: data, encoding: .utf8), !string.isEmpty else { return }

        let lines = string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.logLines.append(contentsOf: lines)
            if self.logLines.count > self.maxRetainedLines {
                self.logLines.removeFirst(self.logLines.count - self.maxRetainedLines)
            }

            for line in lines {
                if let entry = PQCLogEntry.parseTerminalLine(line) {
                    self.entrySubject.send(entry)
                }
            }
        }
    }

    private func appendLog(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.logLines.append(message)
            if self.logLines.count > self.maxRetainedLines {
                self.logLines.removeFirst(self.logLines.count - self.maxRetainedLines)
            }
        }
    }
}

public struct BursaHQTerminalView: View {
    @StateObject private var watcher = PQCFileWatcher()
    @State private var isBoundToMetrics = false

    private let filePath: String
    private let bindToMetrics: Bool
    private let simulateDemoWrites: Bool

    public init(
        filePath: String = PQCFileWatcher.defaultLogFilePath,
        bindToMetrics: Bool = false,
        simulateDemoWrites: Bool = false
    ) {
        self.filePath = filePath
        self.bindToMetrics = bindToMetrics
        self.simulateDemoWrites = simulateDemoWrites
    }

    public var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    Circle().fill(Color.yellow).frame(width: 12, height: 12)
                    Circle().fill(Color.green).frame(width: 12, height: 12)
                    Spacer()
                    Text("amiral@bursa-hq: ~")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                    Spacer()
                    Image(systemName: "lock.shield")
                        .foregroundStyle(QAITokens.Palette.teal)
                }
                .padding()
                .background(Color(red: 0.10, green: 0.10, blue: 0.12))

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(watcher.logLines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(colorForLog(line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 280)
                    .background(Color.black)
                    .onChange(of: watcher.logLines.count) { _, count in
                        guard count > 0 else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(count - 1, anchor: .bottom)
                        }
                    }
                }

                HStack {
                    Text("PQC ENGINE STATUS: ONLINE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.black)
                    Spacer()
                    Text(filePath)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .padding(8)
                .background(Color.green)
            }
            .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
        }
        .accessibilityIdentifier("bursa-hq-terminal")
        .onAppear {
            watcher.startWatching(filePath: filePath)
            if simulateDemoWrites {
                watcher.startDemoWriter(filePath: filePath)
            }
            if bindToMetrics, !isBoundToMetrics {
                PQCLogService.shared.bindExternalFeed(watcher.entryPublisher)
                isBoundToMetrics = true
            }
        }
        .onDisappear {
            watcher.stopWatching()
            if bindToMetrics {
                PQCLogService.shared.useSimulator()
                PQCLogService.shared.startReadingLogs(aiEnabled: QuantumCryptoEngine.shared.isAIOptimized)
                isBoundToMetrics = false
            }
        }
    }

    private func colorForLog(_ text: String) -> Color {
        if text.contains("[SISTEM]") || text.localizedCaseInsensitiveContains("kritik") {
            return .red
        }
        if text.contains("Kyber") || text.contains("Dilithium") || text.contains("Falcon") {
            return .cyan
        }
        if text.contains("Bursa HQ") {
            return .yellow
        }
        return .green
    }
}

#Preview {
    BursaHQTerminalView(simulateDemoWrites: true)
}
