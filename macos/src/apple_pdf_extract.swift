import Foundation
import PDFKit

guard CommandLine.arguments.count > 1 else {
    print("Usage: apple-pdf-extract <pdf_path> [page_number]")
    exit(1)
}

let pdfPath = CommandLine.arguments[1]
let pdfURL = URL(fileURLWithPath: pdfPath)

guard let doc = PDFDocument(url: pdfURL) else {
    print("Error: Cannot open PDF at \(pdfPath)")
    exit(1)
}

let pageCount = doc.pageCount
print("PDF Page Count: \(pageCount)")

if CommandLine.arguments.count > 2, let targetPage = Int(CommandLine.arguments[2]) {
    guard targetPage >= 1 && targetPage <= pageCount else {
        print("Error: Page \(targetPage) out of bounds (1..\(pageCount))")
        exit(1)
    }
    if let page = doc.page(at: targetPage - 1), let text = page.string {
        print("=== PAGE \(targetPage) ===")
        print(text)
    }
} else {
    for i in 0..<pageCount {
        if let page = doc.page(at: i), let text = page.string {
            print("--- Page \(i + 1) ---")
            print(text)
        }
    }
}
