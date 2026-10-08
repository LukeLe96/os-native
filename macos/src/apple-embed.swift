import Foundation
import NaturalLanguage

struct EmbeddingResult: Codable {
    let text: String
    let dimension: Int
    let vector: [Double]
    let latencyMs: Double

    enum CodingKeys: String, CodingKey {
        case text
        case dimension
        case vector
        case latencyMs = "latency_ms"
    }
}

struct SimilarityResult: Codable {
    let text1: String
    let text2: String
    let cosineSimilarity: Double
    let latencyMs: Double

    enum CodingKeys: String, CodingKey {
        case text1
        case text2
        case cosineSimilarity = "cosine_similarity"
        case latencyMs = "latency_ms"
    }
}

func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 0.0 }
    var dot = 0.0
    var normA = 0.0
    var normB = 0.0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    let denom = sqrt(normA) * sqrt(normB)
    return denom == 0.0 ? 0.0 : dot / denom
}

func getSentenceVector(_ text: String) -> [Double]? {
    guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
        return nil
    }
    return embedding.vector(for: text)
}

func printUsage() {
    let usage = """
    apple-embed: High-speed native Apple Silicon sentence embeddings via NaturalLanguage.framework

    Usage:
      apple-embed <text>                       Output 512-dim vector JSON (< 5ms, 0-token)
      apple-embed --cosine <text1> <text2>     Calculate semantic cosine similarity between 2 texts
      apple-embed --raw <text>                 Output raw space-separated numbers (for shell piping)
      apple-embed --dim                        Print embedding dimension (512)
    """
    print(usage)
}

let args = CommandLine.arguments

if args.count < 2 {
    printUsage()
    exit(1)
}

let firstArg = args[1]

if firstArg == "-h" || firstArg == "--help" {
    printUsage()
    exit(0)
}

if firstArg == "--dim" {
    print(512)
    exit(0)
}

let t0 = CFAbsoluteTimeGetCurrent()

if firstArg == "--cosine" {
    guard args.count >= 4 else {
        fputs("Error: --cosine requires two text arguments\n", stderr)
        exit(1)
    }
    let t1 = args[2]
    let t2 = args[3]

    guard let v1 = getSentenceVector(t1), let v2 = getSentenceVector(t2) else {
        fputs("Error: failed to generate embeddings\n", stderr)
        exit(1)
    }

    let sim = cosineSimilarity(v1, v2)
    let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0

    let res = SimilarityResult(text1: t1, text2: t2, cosineSimilarity: (sim * 10000).rounded() / 10000, latencyMs: (elapsed * 10).rounded() / 10)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(res), let jsonStr = String(data: data, encoding: .utf8) {
        print(jsonStr)
    }
    exit(0)
}

if firstArg == "--raw" {
    guard args.count >= 3 else {
        fputs("Error: --raw requires a text argument\n", stderr)
        exit(1)
    }
    let text = args[2]
    guard let vec = getSentenceVector(text) else {
        fputs("Error: failed to generate embedding\n", stderr)
        exit(1)
    }
    let rawStr = vec.map { String(format: "%.6f", $0) }.joined(separator: " ")
    print(rawStr)
    exit(0)
}

// Default: Output JSON with full vector
let text = args.dropFirst().joined(separator: " ")
guard let vec = getSentenceVector(text) else {
    fputs("Error: failed to generate embedding\n", stderr)
    exit(1)
}

let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
let res = EmbeddingResult(text: text, dimension: vec.count, vector: vec, latencyMs: (elapsed * 10).rounded() / 10)

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
if let data = try? encoder.encode(res), let jsonStr = String(data: data, encoding: .utf8) {
    print(jsonStr)
}
