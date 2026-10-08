import Foundation
import SoundAnalysis
import AVFoundation

// MARK: - Models

struct TimeRange: Codable {
    let start: Double
    let end: Double
}

struct ClassificationItem: Codable {
    let category: String
    let displayName: String
    let confidence: Double
    let maxConfidence: Double
    let meanConfidence: Double
    let timeRange: TimeRange
    let occurrences: Int

    enum CodingKeys: String, CodingKey {
        case category
        case displayName = "display_name"
        case confidence
        case maxConfidence = "max_confidence"
        case meanConfidence = "mean_confidence"
        case timeRange = "time_range"
        case occurrences
    }
}

struct WindowClassification: Codable {
    let category: String
    let displayName: String
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case category
        case displayName = "display_name"
        case confidence
    }
}

struct WindowResult: Codable {
    let index: Int
    let timeRange: TimeRange
    let topClassifications: [WindowClassification]

    enum CodingKeys: String, CodingKey {
        case index
        case timeRange = "time_range"
        case topClassifications = "top_classifications"
    }
}

struct SoundAnalysisOutput: Codable {
    let file: String
    let durationSeconds: Double
    let classifier: String
    let windowCount: Int
    let topClassifications: [ClassificationItem]
    let windows: [WindowResult]?
    let latencyMs: Double

    enum CodingKeys: String, CodingKey {
        case file
        case durationSeconds = "duration_seconds"
        case classifier
        case windowCount = "window_count"
        case topClassifications = "top_classifications"
        case windows
        case latencyMs = "latency_ms"
    }
}

// MARK: - Category Stats Accumulator

class CategoryAccumulator {
    let identifier: String
    var maxConfidence: Double = 0.0
    var sumConfidence: Double = 0.0
    var occurrences: Int = 0
    var earliestStart: Double = Double.infinity
    var latestEnd: Double = 0.0

    init(identifier: String) {
        self.identifier = identifier
    }

    func add(confidence: Double, start: Double, end: Double) {
        if confidence > maxConfidence {
            maxConfidence = confidence
        }
        sumConfidence += confidence
        occurrences += 1
        if start < earliestStart {
            earliestStart = start
        }
        if end > latestEnd {
            latestEnd = end
        }
    }

    var meanConfidence: Double {
        return occurrences > 0 ? sumConfidence / Double(occurrences) : 0.0
    }
}

// MARK: - Observer

final class SoundClassificationObserver: NSObject, SNResultsObserving {
    var results: [SNClassificationResult] = []
    var error: Error?

    func request(_ request: SNRequest, didProduce result: SNResult) {
        if let classificationResult = result as? SNClassificationResult {
            results.append(classificationResult)
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        self.error = error
    }

    func requestDidComplete(_ request: SNRequest) {
        // Complete
    }
}

// MARK: - Helper Functions

func formatDisplayName(_ identifier: String) -> String {
    let parts = identifier.split(separator: "_")
    return parts.map { part -> String in
        guard let first = part.first else { return "" }
        return String(first).uppercased() + part.dropFirst()
    }.joined(separator: " ")
}

func roundToDecimals(_ value: Double, places: Int = 4) -> Double {
    let multiplier = pow(10.0, Double(places))
    return (value * multiplier).rounded() / multiplier
}

// Fallback converter for formats unsupported by AVAudioFile (e.g. webm, mkv)
func convertToWAVOnTheFly(sourceURL: URL) -> URL? {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sound_classify_\(UUID().uuidString).wav")

    // Check ffmpeg candidates
    let ffmpegCandidates = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ]
    for bin in ffmpegCandidates where FileManager.default.isExecutableFile(atPath: bin) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["-y", "-i", sourceURL.path, "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1", tempURL.path]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus == 0 && FileManager.default.fileExists(atPath: tempURL.path) {
                return tempURL
            }
        } catch {}
    }

    // Try afconvert
    let afBin = "/usr/bin/afconvert"
    if FileManager.default.isExecutableFile(atPath: afBin) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: afBin)
        p.arguments = ["-f", "WAVE", "-d", "LEI16@16000", "-c", "1", sourceURL.path, tempURL.path]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus == 0 && FileManager.default.fileExists(atPath: tempURL.path) {
                return tempURL
            }
        } catch {}
    }

    return nil
}

// Pads audio with silence to minDuration if shorter
func padAudioIfNeeded(sourceURL: URL, minDuration: Double = 1.0) -> (URL, Bool, Double) {
    guard let file = try? AVAudioFile(forReading: sourceURL) else {
        return (sourceURL, false, 0.0)
    }

    let actualDuration = Double(file.length) / file.processingFormat.sampleRate
    if actualDuration >= minDuration {
        return (sourceURL, false, actualDuration)
    }

    let format = file.processingFormat
    let targetFrames = AVAudioFrameCount(format.sampleRate * max(minDuration, 1.0))
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: targetFrames) else {
        return (sourceURL, false, actualDuration)
    }

    let framesToRead = AVAudioFrameCount(file.length)
    if framesToRead > 0 {
        try? file.read(into: buffer, frameCount: framesToRead)
    }
    buffer.frameLength = targetFrames

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sound_padded_\(UUID().uuidString).wav")
    do {
        let outFile = try AVAudioFile(forWriting: tempURL, settings: file.fileFormat.settings)
        try outFile.write(from: buffer)
        return (tempURL, true, actualDuration)
    } catch {
        return (sourceURL, false, actualDuration)
    }
}

// MARK: - CLI Application

@main
struct AppleSoundClassifyCLI {
    static let version = "1.0.0"

    static func printUsage() {
        let text = """
        apple-sound-classify: Native Apple Silicon Sound Classifier (0-token, offline)
        Powered by Apple SoundAnalysis.framework (SNClassifySoundRequest v1, 300+ sound taxonomy)

        Usage:
          apple-sound-classify <audio_path> [options]

        Options:
          --top <n>             Number of top sound categories to return (default: 5)
          --threshold <float>   Minimum confidence threshold (0.0 - 1.0, default: 0.10)
          --json                Output structured JSON
          --timeline            Include per-window classification timeline
          --lines               Print one classification per line in text mode
          --window <seconds>    Analysis window duration in seconds (default: 1.0s)
          --overlap <float>     Window overlap factor (0.0 - 0.9, default: 0.5)
          -v, --version         Print version information
          -h, --help            Show this help message

        Examples:
          apple-sound-classify voice.m4a
          apple-sound-classify meeting.wav --top 3 --threshold 0.20
          apple-sound-classify effect.mp3 --json
          apple-sound-classify ambient.caf --timeline --lines
        """
        print(text)
    }

    static func main() {
        let args = CommandLine.arguments

        if args.count < 2 {
            printUsage()
            exit(1)
        }

        var inputPath: String?
        var topCount: Int = 5
        var threshold: Double = 0.10
        var outputJSON: Bool = false
        var showTimeline: Bool = false
        var printLines: Bool = false
        var windowDurationSec: Double = 1.0
        var overlapFactor: Double = 0.5

        var i = 1
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-h", "--help":
                printUsage()
                exit(0)
            case "-v", "--version":
                print("apple-sound-classify version \(version)")
                exit(0)
            case "--json":
                outputJSON = true
            case "--timeline":
                showTimeline = true
            case "--lines":
                printLines = true
            case "--top", "-t", "-n":
                if i + 1 < args.count, let val = Int(args[i + 1]), val > 0 {
                    topCount = val
                    i += 1
                } else {
                    fputs("Error: --top requires a positive integer argument\n", stderr)
                    exit(1)
                }
            case "--threshold", "-th":
                if i + 1 < args.count, let val = Double(args[i + 1]), val >= 0.0 && val <= 1.0 {
                    threshold = val
                    i += 1
                } else {
                    fputs("Error: --threshold requires a float between 0.0 and 1.0\n", stderr)
                    exit(1)
                }
            case "--window", "-w":
                if i + 1 < args.count, let val = Double(args[i + 1]), val >= 0.2 && val <= 10.0 {
                    windowDurationSec = val
                    i += 1
                } else {
                    fputs("Error: --window requires a duration in seconds between 0.2 and 10.0\n", stderr)
                    exit(1)
                }
            case "--overlap":
                if i + 1 < args.count, let val = Double(args[i + 1]), val >= 0.0 && val < 1.0 {
                    overlapFactor = val
                    i += 1
                } else {
                    fputs("Error: --overlap requires a float between 0.0 and 0.9\n", stderr)
                    exit(1)
                }
            default:
                if arg.hasPrefix("-") {
                    fputs("Error: Unknown option '\(arg)'\n", stderr)
                    printUsage()
                    exit(1)
                } else {
                    inputPath = arg
                }
            }
            i += 1
        }

        guard let targetPath = inputPath else {
            fputs("Error: Missing audio file path\n", stderr)
            printUsage()
            exit(1)
        }

        let fileManager = FileManager.default
        let expandedPath = NSString(string: targetPath).expandingTildeInPath
        let originalURL = URL(fileURLWithPath: expandedPath)

        guard fileManager.fileExists(atPath: originalURL.path) else {
            fputs("Error: File not found: \(targetPath)\n", stderr)
            exit(1)
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        var tempFilesToClean: [URL] = []
        defer {
            for tempURL in tempFilesToClean {
                try? fileManager.removeItem(at: tempURL)
            }
        }

        var sourceURL = originalURL

        // Verify if AVAudioFile can read the file; if not, try on-the-fly conversion
        if (try? AVAudioFile(forReading: sourceURL)) == nil {
            if let converted = convertToWAVOnTheFly(sourceURL: sourceURL) {
                tempFilesToClean.append(converted)
                sourceURL = converted
            } else {
                fputs("Error: Unable to decode audio format for file: \(targetPath)\n", stderr)
                exit(1)
            }
        }

        // Check duration and pad with silence if duration is shorter than window duration
        let (analyzableURL, wasPadded, originalDuration) = padAudioIfNeeded(sourceURL: sourceURL, minDuration: windowDurationSec)
        if wasPadded {
            tempFilesToClean.append(analyzableURL)
        }

        let effectiveDuration = originalDuration > 0 ? originalDuration : windowDurationSec

        // Setup Analyzer and Request
        let analyzer: SNAudioFileAnalyzer
        do {
            analyzer = try SNAudioFileAnalyzer(url: analyzableURL)
        } catch {
            fputs("Error initializing SNAudioFileAnalyzer: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        let request: SNClassifySoundRequest
        do {
            request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.windowDuration = CMTime(seconds: windowDurationSec, preferredTimescale: 16000)
            request.overlapFactor = overlapFactor
        } catch {
            fputs("Error creating SNClassifySoundRequest: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        let observer = SoundClassificationObserver()
        do {
            try analyzer.add(request, withObserver: observer)
        } catch {
            fputs("Error adding request to analyzer: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        // Perform analysis synchronously
        analyzer.analyze()

        if let err = observer.error {
            fputs("Error during sound classification: \(err.localizedDescription)\n", stderr)
            exit(1)
        }

        let rawResults = observer.results

        // Aggregate statistics across windows
        var categoryMap: [String: CategoryAccumulator] = [:]
        var windowResults: [WindowResult] = []

        for (winIdx, winResult) in rawResults.enumerated() {
            let winStart = CMTimeGetSeconds(winResult.timeRange.start)
            let winDur = CMTimeGetSeconds(winResult.timeRange.duration)
            let winEnd = min(winStart + winDur, effectiveDuration)

            var topWindowClasses: [WindowClassification] = []

            for classification in winResult.classifications {
                let id = classification.identifier
                let conf = Double(classification.confidence)

                if conf >= threshold {
                    let accum = categoryMap[id] ?? CategoryAccumulator(identifier: id)
                    accum.add(confidence: conf, start: winStart, end: winEnd)
                    categoryMap[id] = accum
                }

                if topWindowClasses.count < topCount && conf >= threshold {
                    topWindowClasses.append(WindowClassification(
                        category: id,
                        displayName: formatDisplayName(id),
                        confidence: roundToDecimals(conf, places: 4)
                    ))
                }
            }

            if showTimeline || outputJSON {
                windowResults.append(WindowResult(
                    index: winIdx,
                    timeRange: TimeRange(start: roundToDecimals(winStart, places: 2), end: roundToDecimals(winEnd, places: 2)),
                    topClassifications: topWindowClasses
                ))
            }
        }

        // Filter and sort top categories by peak confidence
        let sortedCategories = categoryMap.values
            .filter { $0.maxConfidence >= threshold }
            .sorted { $0.maxConfidence > $1.maxConfidence }
            .prefix(topCount)

        let topClassifications: [ClassificationItem] = sortedCategories.map { accum in
            let clampedStart = max(0.0, min(accum.earliestStart, effectiveDuration))
            let clampedEnd = max(clampedStart, min(accum.latestEnd, effectiveDuration))

            return ClassificationItem(
                category: accum.identifier,
                displayName: formatDisplayName(accum.identifier),
                confidence: roundToDecimals(accum.maxConfidence, places: 4),
                maxConfidence: roundToDecimals(accum.maxConfidence, places: 4),
                meanConfidence: roundToDecimals(accum.meanConfidence, places: 4),
                timeRange: TimeRange(
                    start: roundToDecimals(clampedStart, places: 2),
                    end: roundToDecimals(clampedEnd, places: 2)
                ),
                occurrences: accum.occurrences
            )
        }

        let elapsedTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        if outputJSON {
            let output = SoundAnalysisOutput(
                file: expandedPath,
                durationSeconds: roundToDecimals(effectiveDuration, places: 3),
                classifier: "com.apple.SoundAnalysis.classifier.v1",
                windowCount: rawResults.count,
                topClassifications: topClassifications,
                windows: showTimeline ? windowResults : nil,
                latencyMs: roundToDecimals(elapsedTime, places: 1)
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            if let data = try? encoder.encode(output), let jsonStr = String(data: data, encoding: .utf8) {
                print(jsonStr)
            }
            exit(0)
        }

        // Human-Readable Output
        if topClassifications.isEmpty {
            print("No sounds detected above threshold \(String(format: "%.2f", threshold)) in \(targetPath)")
            exit(0)
        }

        if printLines {
            let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
            print("Top sound classifications for \(fileName) (\(String(format: "%.2f", effectiveDuration))s):")
            for (idx, item) in topClassifications.enumerated() {
                let rangeStr = String(format: "%.2fs - %.2fs", item.timeRange.start, item.timeRange.end)
                print(String(format: "  %d. %@ (%@): %.2f (peak: %.2f, avg: %.2f, time: %@, hits: %d)",
                             idx + 1, item.displayName, item.category, item.confidence, item.maxConfidence, item.meanConfidence, rangeStr, item.occurrences))
            }
        } else {
            // Standard clean comma-separated list: 1. Speech (0.95), 2. Laughter (0.32)...
            let listString = topClassifications.enumerated().map { (idx, item) in
                "\(idx + 1). \(item.displayName) (\(String(format: "%.2f", item.confidence)))"
            }.joined(separator: ", ")
            print(listString)
        }

        if showTimeline && !windowResults.isEmpty {
            print("\nTimeline breakdown (\(windowResults.count) windows):")
            for win in windowResults {
                let timeStr = String(format: "[%.2fs - %.2fs]", win.timeRange.start, win.timeRange.end)
                let classesStr = win.topClassifications.map { "\($0.displayName) (\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", ")
                print("  \(timeStr): \(classesStr.isEmpty ? "None" : classesStr)")
            }
        }
    }
}
