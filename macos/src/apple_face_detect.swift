import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1 else {
    print("Usage: apple-face-detect <input_image>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let inputURL = URL(fileURLWithPath: inputPath)

guard let ciImage = CIImage(contentsOf: inputURL) else {
    print("Error: Cannot load image at \(inputPath)")
    exit(1)
}

let startTime = CFAbsoluteTimeGetCurrent()
let request = VNDetectFaceLandmarksRequest()
let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

do {
    try handler.perform([request])
    let faces = request.results ?? []
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("=== FACE DETECTION (Processed in \(String(format: "%.3f", elapsed))s) ===")
    print("Total faces detected: \(faces.count)")
    for (i, face) in faces.enumerated() {
        let box = face.boundingBox
        print(String(format: "- Face #%d: Box [x: %.3f, y: %.3f, w: %.3f, h: %.3f], Confidence: %.2f", i + 1, box.origin.x, box.origin.y, box.size.width, box.size.height, face.confidence))
        if let landmarks = face.landmarks {
            let hasEyes = landmarks.leftEye != nil && landmarks.rightEye != nil
            let hasMouth = landmarks.outerLips != nil
            print("  Landmarks: Eyes=\(hasEyes), Mouth=\(hasMouth), Nose=\(landmarks.nose != nil)")
        }
    }
} catch {
    print("Error detecting faces: \(error.localizedDescription)")
    exit(1)
}
