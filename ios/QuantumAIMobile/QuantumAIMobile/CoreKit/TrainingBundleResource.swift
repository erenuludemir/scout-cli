import Foundation

enum TrainingBundleResource {
    struct HTMLDocument {
        let html: String
        let baseURL: URL
    }

    static var trainingHTMLURL: URL? {
        ResourceBundle.url(forResource: "TrainingV140721", withExtension: "html", subdirectory: "Training")
    }

    static var trainingHTMLDocument: HTMLDocument? {
        guard
            let url = trainingHTMLURL,
            let html = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }

        return HTMLDocument(html: html, baseURL: url.deletingLastPathComponent())
    }

    static var trainingPDFURL: URL? {
        ResourceBundle.url(forResource: "Training_v2", withExtension: "pdf", subdirectory: "Training")
    }
}
