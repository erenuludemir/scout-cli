import Foundation

private final class ResourceBundleFinder {}

enum ResourceBundle {
    static let current: Bundle = candidates.first ?? .main

    static func url(forResource name: String, withExtension ext: String?, subdirectory: String? = nil) -> URL? {
        let candidateSubdirectories = normalizedSubdirectories(from: subdirectory)

        for bundle in candidates {
            for directory in candidateSubdirectories {
                if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: directory) {
                    return url
                }
            }

            if let recursiveURL = recursivelyFindResource(in: bundle, name: name, ext: ext) {
                return recursiveURL
            }
        }

        return nil
    }

    private static let candidates: [Bundle] = {
        var bundles: [Bundle] = []

        #if SWIFT_PACKAGE
        bundles.append(.module)
        #endif

        bundles.append(Bundle(for: ResourceBundleFinder.self))
        bundles.append(.main)

        if let resourceURL = Bundle.main.resourceURL {
            let packageBundleURL = resourceURL.appendingPathComponent("QuantumAIMobile_QuantumAIMobile.bundle")
            if let packageBundle = Bundle(url: packageBundleURL) {
                bundles.append(packageBundle)
            }
        }

        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)

        var seen = Set<URL>()
        return bundles.filter { bundle in
            let url = bundle.bundleURL.standardizedFileURL
            return seen.insert(url).inserted
        }
    }()

    private static func normalizedSubdirectories(from subdirectory: String?) -> [String?] {
        guard let subdirectory, !subdirectory.isEmpty else {
            return [nil]
        }

        var candidates: [String?] = [subdirectory]
        let trimmed = subdirectory.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let lastComponent = trimmed.split(separator: "/").last.map(String.init)

        if lastComponent != subdirectory {
            candidates.append(lastComponent)
        }

        candidates.append(nil)

        var seen = Set<String>()
        var normalized: [String?] = []
        for candidate in candidates {
            let key = candidate ?? "<nil>"
            if seen.insert(key).inserted {
                normalized.append(candidate)
            }
        }
        return normalized
    }

    private static func recursivelyFindResource(in bundle: Bundle, name: String, ext: String?) -> URL? {
        guard let resourceURL = bundle.resourceURL else { return nil }

        let fileName = [name, ext].compactMap { $0 }.joined(separator: ".")
        let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.lastPathComponent == fileName else { continue }
            return fileURL
        }

        return nil
    }
}
