import Foundation

enum TrainingBundleResource {
    struct HTMLDocument {
        let html: String
        let baseURL: URL
    }

    private static let cachedTrainingHTMLURL = ResourceBundle.url(
        forResource: "TrainingV140721",
        withExtension: "html",
        subdirectory: "Training"
    )
    private static let cachedTrainingHTMLDocument: HTMLDocument? = {
        guard
            let url = cachedTrainingHTMLURL,
            let html = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }

        return HTMLDocument(html: html, baseURL: url.deletingLastPathComponent())
    }()

    static var trainingHTMLURL: URL? {
        cachedTrainingHTMLURL
    }

    static var trainingHTMLDocument: HTMLDocument? {
        cachedTrainingHTMLDocument
    }

    static var trainingPDFURL: URL? {
        ResourceBundle.url(forResource: "Training_v2", withExtension: "pdf", subdirectory: "Training")
    }
}
