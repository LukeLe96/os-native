import Foundation
import NaturalLanguage

guard CommandLine.arguments.count > 2 else {
    print("Usage:")
    print("  apple-semantic --dist <word1> <word2>      (Calculate semantic distance)")
    print("  apple-semantic --neighbors <word> [count]  (Find semantic neighbors)")
    exit(1)
}

let mode = CommandLine.arguments[1]

guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
    print("Error: English word embedding not available.")
    exit(1)
}

if mode == "--dist" {
    let w1 = CommandLine.arguments[2]
    let w2 = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : ""
    let dist = embedding.distance(between: w1, and: w2)
    print(String(format: "Semantic distance between '%@' and '%@': %.4f (0 = identical, 2 = unrelated)", w1, w2, dist))
} else if mode == "--neighbors" {
    let w = CommandLine.arguments[2]
    let count = CommandLine.arguments.count > 3 ? (Int(CommandLine.arguments[3]) ?? 5) : 5
    let neighbors = embedding.neighbors(for: w, maximumCount: count)
    print("=== Semantic Neighbors for '\(w)' ===")
    for (item, dist) in neighbors {
        print(String(format: "- %-15@ (distance: %.4f)", item, dist))
    }
} else {
    print("Unknown mode: \(mode)")
    exit(1)
}
