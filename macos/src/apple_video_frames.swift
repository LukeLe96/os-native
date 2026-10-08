import Foundation
import AVFoundation
import Vision
import AppKit

func printUsage() {
    print("""
    Usage: apple-video-frames <video_path> [options]
    Options:
      --count <n>       Number of keyframes to extract (default: 3)
      --out-dir <dir>   Output directory (default: temp folder)
      --analyze         Run Apple Vision on extracted frames (OCR + Classification + Face detection)
      --json            Output results as JSON
    """)
}

struct FrameAnalysis: Codable {
    let index: Int
    let timestampSeconds: Double
    let filePath: String
    var ocrText: String?
    var classifications: [String]?
    var faceCount: Int?
}

struct VideoReport: Codable {
    let videoPath: String
    let durationSeconds: Double
    let frameCount: Int
    let frames: [FrameAnalysis]
    let summary: String
}

var videoPath = ""
var frameCount = 3
var outDir = NSTemporaryDirectory()
var shouldAnalyze = false
var jsonOutput = false

var i = 1
while i < CommandLine.arguments.count {
    let arg = CommandLine.arguments[i]
    if arg == "--count" && i + 1 < CommandLine.arguments.count {
        frameCount = Int(CommandLine.arguments[i + 1]) ?? 3
        i += 2
    } else if arg == "--out-dir" && i + 1 < CommandLine.arguments.count {
        outDir = CommandLine.arguments[i + 1]
        i += 2
    } else if arg == "--analyze" {
        shouldAnalyze = true
        i += 1
    } else if arg == "--json" {
        jsonOutput = true
        i += 1
    } else if videoPath.isEmpty && !arg.hasPrefix("-") {
        videoPath = arg
        i += 1
    } else {
        i += 1
    }
}

guard !videoPath.isEmpty else {
    printUsage()
    exit(1)
}

let videoURL = URL(fileURLWithPath: videoPath)
guard FileManager.default.fileExists(atPath: videoPath) else {
    fputs("Error: File not found: \(videoPath)\n", stderr)
    exit(1)
}

let asset = AVURLAsset(url: videoURL)
let duration = CMTimeGetSeconds(asset.duration)

if duration <= 0 || duration.isNaN {
    fputs("Error: Could not determine video duration\n", stderr)
    exit(1)
}

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

// Calculate timestamps evenly spaced across the video duration (e.g. 25%, 50%, 75%)
var targetTimes: [Double] = []
if frameCount == 1 {
    targetTimes.append(duration > 2.0 ? min(duration * 0.35, 2.0) : duration * 0.5)
} else {
    for idx in 1...frameCount {
        let frac = Double(idx) / Double(frameCount + 1)
        targetTimes.append(duration * frac)
    }
}

var analyses: [FrameAnalysis] = []
let baseName = (videoPath as NSString).lastPathComponent.replacingOccurrences(of: ".", with: "_")
let runID = UUID().uuidString.prefix(8)

for (idx, sec) in targetTimes.enumerated() {
    let cmTime = CMTime(seconds: sec, preferredTimescale: 600)
    do {
        let cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
        let frameFile = (outDir as NSString).appendingPathComponent("frame_\(baseName)_\(runID)_\(idx + 1).jpg")
        let frameURL = URL(fileURLWithPath: frameFile)
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
            try jpegData.write(to: frameURL)
        }
        
        var analysis = FrameAnalysis(index: idx + 1, timestampSeconds: round(sec * 100) / 100, filePath: frameFile)
        
        if shouldAnalyze {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // 1. Classification
            let classReq = VNClassifyImageRequest()
            // 2. Face detect
            let faceReq = VNDetectFaceRectanglesRequest()
            // 3. OCR (VNRecognizeTextRequest)
            let ocrReq = VNRecognizeTextRequest()
            ocrReq.recognitionLevel = .accurate
            ocrReq.recognitionLanguages = ["vi-VN", "en-US"]
            ocrReq.usesLanguageCorrection = true
            
            try? handler.perform([classReq, faceReq, ocrReq])
            
            // Classes
            if let classRes = classReq.results {
                let topClasses = classRes.filter { $0.confidence > 0.20 }.prefix(4).map { $0.identifier }
                analysis.classifications = Array(topClasses)
            }
            
            // Faces
            analysis.faceCount = faceReq.results?.count ?? 0
            
            // OCR
            if let ocrRes = ocrReq.results {
                let lines = ocrRes.compactMap { $0.topCandidates(1).first?.string }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !lines.isEmpty {
                    analysis.ocrText = lines.joined(separator: "\n")
                }
            }
        }
        
        analyses.append(analysis)
    } catch {
        fputs("Warning: Failed to capture frame at \(sec)s: \(error.localizedDescription)\n", stderr)
    }
}

var summaryLines: [String] = []
for a in analyses {
    var desc = "Frame #\(a.index) (\(String(format: "%.1f", a.timestampSeconds))s):"
    if let c = a.classifications, !c.isEmpty {
        desc += " Bối cảnh: [\(c.joined(separator: ", "))]"
    }
    if let fc = a.faceCount, fc > 0 {
        desc += " | Phát hiện \(fc) khuôn mặt"
    }
    if let ocr = a.ocrText, !ocr.isEmpty {
        let clean = ocr.replacingOccurrences(of: "\n", with: " ")
        let snippet = clean.count > 120 ? String(clean.prefix(120)) + "..." : clean
        desc += " | Chữ trong frame: \"\(snippet)\""
    }
    summaryLines.append(desc)
}

let report = VideoReport(
    videoPath: videoPath,
    durationSeconds: round(duration * 100) / 100,
    frameCount: analyses.count,
    frames: analyses,
    summary: summaryLines.joined(separator: "\n")
)

if jsonOutput {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(report), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
} else {
    print("=== APPLE NATIVE VIDEO FRAMES & VISION REPORT ===")
    print("Video: \(videoPath)")
    print("Duration: \(String(format: "%.2f", duration))s | Extracted Frames: \(analyses.count)")
    print("-------------------------------------------------")
    for line in summaryLines {
        print("- \(line)")
    }
    print("-------------------------------------------------")
    print("Files saved to:")
    for a in analyses {
        print("  \(a.filePath)")
    }
}
