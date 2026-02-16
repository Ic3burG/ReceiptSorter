import PDFKit
import SwiftUI

struct PDFKitRepresentedView: NSViewRepresentable {
  let url: URL

  func makeNSView(context: Context) -> PDFView {
    let pdfView = PDFView()
    pdfView.autoScales = true
    pdfView.displayMode = .singlePageContinuous
    pdfView.backgroundColor = .controlBackgroundColor
    return pdfView
  }

  func updateNSView(_ pdfView: PDFView, context: Context) {
    if pdfView.document?.documentURL != url {
      if let document = PDFDocument(url: url) {
        pdfView.document = document
      }
    }
  }
}
