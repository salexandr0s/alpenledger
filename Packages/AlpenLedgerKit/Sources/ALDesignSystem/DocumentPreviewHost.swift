import PDFKit
import SwiftUI

public struct DocumentPreviewHost: View {
    private let fileURL: URL?
    private let mediaType: String

    public init(fileURL: URL?, mediaType: String) {
        self.fileURL = fileURL
        self.mediaType = mediaType
    }

    public var body: some View {
        Group {
            if let fileURL {
                if mediaType == "application/pdf" || fileURL.pathExtension.lowercased() == "pdf" {
                    PDFPreview(fileURL: fileURL)
                } else if let image = NSImage(contentsOf: fileURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(AppTheme.spacingM)
                } else {
                    ContentUnavailableView("Preview Unavailable", systemImage: "doc")
                }
            } else {
                ContentUnavailableView("No Document Selected", systemImage: "doc.text")
            }
        }
    }
}

private struct PDFPreview: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.setAccessibilityIdentifier("documents.previewPane")
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: fileURL)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(url: fileURL)
    }
}
