import Foundation
import PDFKit
import AppKit

guard CommandLine.arguments.count > 2 else {
    print("Usage: apple-pdf-render <pdf_path> <output_dir> [scale_factor=2.0]")
    exit(1)
}

let pdfPath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
let scale: CGFloat = CommandLine.arguments.count > 3 ? CGFloat(Double(CommandLine.arguments[3]) ?? 2.0) : 2.0

let pdfURL = URL(fileURLWithPath: pdfPath)
guard let doc = PDFDocument(url: pdfURL) else {
    print("Error: Cannot open PDF at \(pdfPath)")
    exit(1)
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let startTime = CFAbsoluteTimeGetCurrent()
let pageCount = doc.pageCount

for i in 0..<pageCount {
    guard let page = doc.page(at: i) else { continue }
    let pageBounds = page.bounds(for: .mediaBox)
    let pixelSize = NSSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
    
    let image = NSImage(size: pixelSize)
    image.lockFocus()
    if let context = NSGraphicsContext.current?.cgContext {
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: pixelSize))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
    }
    image.unlockFocus()
    
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        continue
    }
    
    let outPath = "\(outDir)/page_\(String(format: "%03d", i + 1)).png"
    try? pngData.write(to: URL(fileURLWithPath: outPath))
    print("Rendered: \(outPath)")
}

let elapsed = CFAbsoluteTimeGetCurrent() - startTime
print(String(format: "Rendered %d pages in %.3f seconds", pageCount, elapsed))
