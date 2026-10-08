import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1 else {
    print("[]")
    exit(0)
}

let inputPath = CommandLine.arguments[1]
let inputURL = URL(fileURLWithPath: inputPath)

guard let ciImage = CIImage(contentsOf: inputURL) else {
    print("[]")
    exit(0)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["vi-VT", "en-US"]
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

struct OCRItem: Codable {
    let text: String
    let confidence: Float
    let box: [String: Double] // x, y, width, height (y is bottom-left in Vision)
}

do {
    try handler.perform([request])
    let observations = request.results ?? []
    var items: [OCRItem] = []
    
    for observation in observations {
        if let topCandidate = observation.topCandidates(1).first {
            let b = observation.boundingBox
            let boxDict = [
                "x": Double(b.origin.x),
                "y": Double(b.origin.y),
                "width": Double(b.size.width),
                "height": Double(b.size.height)
            ]
            items.append(OCRItem(text: topCandidate.string, confidence: topCandidate.confidence, box: boxDict))
        }
    }
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(items), let jsonStr = String(data: data, encoding: .utf8) {
        print(jsonStr)
    } else {
        print("[]")
    }
} catch {
    print("[]")
}
