import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1 else {
    print("Usage: apple-body-pose <input_image>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let inputURL = URL(fileURLWithPath: inputPath)

guard let ciImage = CIImage(contentsOf: inputURL) else {
    print("Error: Cannot load image at \(inputPath)")
    exit(1)
}

let startTime = CFAbsoluteTimeGetCurrent()
let request = VNDetectHumanBodyPoseRequest()
let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

do {
    try handler.perform([request])
    let bodies = request.results ?? []
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("=== BODY POSE DETECTION (Processed in \(String(format: "%.3f", elapsed))s) ===")
    print("Total bodies detected: \(bodies.count)")
    
    for (i, body) in bodies.enumerated() {
        print("\n--- Person #\(i + 1) ---")
        let points = try body.recognizedPoints(.all)
        
        let joints: [(String, VNHumanBodyPoseObservation.JointName)] = [
            ("Nose", .nose),
            ("Neck", .neck),
            ("Right Shoulder", .rightShoulder),
            ("Left Shoulder", .leftShoulder),
            ("Right Wrist", .rightWrist),
            ("Left Wrist", .leftWrist),
            ("Right Ankle", .rightAnkle),
            ("Left Ankle", .leftAnkle)
        ]
        
        for (name, joint) in joints {
            if let pt = points[joint], pt.confidence > 0.3 {
                print(String(format: "  - %-15@: [x: %.3f, y: %.3f] (conf: %.2f)", name, pt.location.x, pt.location.y, pt.confidence))
            }
        }
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
