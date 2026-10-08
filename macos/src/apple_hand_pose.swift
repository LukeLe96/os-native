import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1 else {
    print("Usage: apple-hand-pose <input_image>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let inputURL = URL(fileURLWithPath: inputPath)

guard let ciImage = CIImage(contentsOf: inputURL) else {
    print("Error: Cannot load image at \(inputPath)")
    exit(1)
}

let startTime = CFAbsoluteTimeGetCurrent()
let request = VNDetectHumanHandPoseRequest()
request.maximumHandCount = 2

let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

do {
    try handler.perform([request])
    let hands = request.results ?? []
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("=== HAND POSE DETECTION (Processed in \(String(format: "%.3f", elapsed))s) ===")
    print("Total hands detected: \(hands.count)")
    
    for (i, hand) in hands.enumerated() {
        print("\n--- Hand #\(i + 1) (Chirality: \(hand.chirality)) ---")
        let points = try hand.recognizedPoints(.all)
        
        let keyJoints: [(String, VNHumanHandPoseObservation.JointName)] = [
            ("Wrist", .wrist),
            ("Thumb Tip", .thumbTip),
            ("Index Tip", .indexTip),
            ("Middle Tip", .middleTip),
            ("Ring Tip", .ringTip),
            ("Little Tip", .littleTip)
        ]
        
        for (name, joint) in keyJoints {
            if let pt = points[joint], pt.confidence > 0.3 {
                print(String(format: "  - %-12@: [x: %.3f, y: %.3f] (conf: %.2f)", name, pt.location.x, pt.location.y, pt.confidence))
            }
        }
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
