import Foundation
import Vision
import AppKit
import CoreGraphics

// MARK: - Data Models

struct ElementBBox: Codable {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

struct Point2D: Codable {
    let x: Int
    let y: Int
}

struct NormalizedBox: Codable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

struct UIElement: Codable {
    var id: String
    var type: String       // "button", "input", "link", "text"
    var text: String
    var confidence: Double
    var bbox: ElementBBox
    var center: Point2D
    var normalized: NormalizedBox
}

struct ImageMetadata: Codable {
    let path: String
    let width: Int
    let height: Int
}

struct UIResult: Codable {
    let image: ImageMetadata
    let executionMs: Double
    let totalCount: Int
    let elements: [UIElement]
}

struct TargetMatchResult: Codable {
    let matched: Bool
    let target: String
    let element: UIElement?
    let click: Point2D?
    let executionMs: Double
}

// MARK: - Internal Helper Structures

struct RawRect {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let confidence: Float
    
    var area: Double { w * h }
    var right: Double { x + w }
    var bottom: Double { y + h }
    var centerX: Double { x + w / 2.0 }
    var centerY: Double { y + h / 2.0 }
}

struct RawText {
    var text: String
    var confidence: Float
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    
    var right: Double { x + w }
    var bottom: Double { y + h }
    var centerX: Double { x + w / 2.0 }
    var centerY: Double { y + h / 2.0 }
}

func round2(_ val: Double) -> Double {
    return (val * 100.0).rounded() / 100.0
}

func round4(_ val: Double) -> Double {
    return (val * 10000.0).rounded() / 10000.0
}

func pad(_ s: String, _ width: Int) -> String {
    if s.count >= width {
        return String(s.prefix(width))
    }
    return s + String(repeating: " ", count: width - s.count)
}

func computeIoU(b1: ElementBBox, b2: ElementBBox) -> Double {
    let xA = max(b1.x, b2.x)
    let yA = max(b1.y, b2.y)
    let xB = min(b1.x + b1.w, b2.x + b2.w)
    let yB = min(b1.y + b1.h, b2.y + b2.h)
    
    let interW = max(0, xB - xA)
    let interH = max(0, yB - yA)
    let interArea = Double(interW * interH)
    let b1Area = Double(b1.w * b1.h)
    let b2Area = Double(b2.w * b2.h)
    let unionArea = b1Area + b2Area - interArea
    return unionArea > 0 ? (interArea / unionArea) : 0
}

func printHelp() {
    let help = """
    apple-ui-detect: Native Zero-Token UI Element & Interactive Target Detector (Apple Silicon)
    
    Usage:
      apple-ui-detect <image_path> [options]
    
    Options:
      -t, --target <query>       Search for a specific UI element/label (case-insensitive)
      --type <filter>            Filter by type: button, input, link, text, all (default: all)
      --fast                     Use fast recognition (~30ms) instead of accurate (~90ms)
      --show-crosshairs          Render center crosshairs on debug images (default: subtle corner markers)
      --draw <output.png>        Render clean annotated visual bounding boxes to an image
      --summary                  Print human-readable table/summary instead of JSON
      -h, --help                 Show this help message
    
    Examples:
      apple-ui-detect screen.png
      apple-ui-detect screen.png --target "Rút tiền"
      apple-ui-detect screen.png --type button --summary
      apple-ui-detect screen.png --draw annotated.png
    """
    print(help)
}

// MARK: - Main Execution

let args = CommandLine.arguments

if args.count < 2 || args.contains("-h") || args.contains("--help") {
    printHelp()
    exit(args.count < 2 ? 1 : 0)
}

let imagePath = args[1]
var targetQuery: String? = nil
var typeFilter: String = "all"
var isFast: Bool = false
var showCrosshairs: Bool = false
var drawOutputPath: String? = nil
var isSummary: Bool = false

var i = 2
while i < args.count {
    let arg = args[i]
    if arg == "-t" || arg == "--target" {
        if i + 1 < args.count {
            targetQuery = args[i + 1]
            i += 1
        }
    } else if arg == "--type" {
        if i + 1 < args.count {
            typeFilter = args[i + 1].lowercased()
            i += 1
        }
    } else if arg == "--fast" {
        isFast = true
    } else if arg == "--show-crosshairs" {
        showCrosshairs = true
    } else if arg == "--draw" {
        if i + 1 < args.count {
            drawOutputPath = args[i + 1]
            i += 1
        }
    } else if arg == "--summary" {
        isSummary = true
    }
    i += 1
}

let inputURL = URL(fileURLWithPath: imagePath)
guard let ciImage = CIImage(contentsOf: inputURL) else {
    fputs("Error: Cannot load image at \(imagePath)\n", stderr)
    exit(1)
}

let imgWidth = Double(ciImage.extent.width)
let imgHeight = Double(ciImage.extent.height)

if imgWidth <= 0 || imgHeight <= 0 {
    fputs("Error: Invalid image dimensions for \(imagePath)\n", stderr)
    exit(1)
}

let startTime = CFAbsoluteTimeGetCurrent()

// Setup Vision Requests
let textReq = VNRecognizeTextRequest()
textReq.recognitionLevel = isFast ? .fast : .accurate
textReq.recognitionLanguages = ["vi-VT", "en-US"]
textReq.usesLanguageCorrection = !isFast

let rectReq = VNDetectRectanglesRequest()
rectReq.maximumObservations = 60
rectReq.minimumConfidence = 0.30
rectReq.minimumAspectRatio = 0.05
rectReq.maximumAspectRatio = 25.0
rectReq.minimumSize = 0.015

let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
do {
    try handler.perform([textReq, rectReq])
} catch {
    fputs("Error performing Vision requests: \(error.localizedDescription)\n", stderr)
    exit(1)
}

let elapsedMs = round2((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

// Extract Raw Texts
var rawTexts: [RawText] = []
for t in textReq.results ?? [] {
    guard let candidate = t.topCandidates(1).first else { continue }
    let str = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
    if str.isEmpty { continue }
    let b = t.boundingBox
    let px = Double(b.origin.x) * imgWidth
    let py = Double(1.0 - b.origin.y - b.size.height) * imgHeight
    let pw = Double(b.size.width) * imgWidth
    let ph = Double(b.size.height) * imgHeight
    rawTexts.append(RawText(text: str, confidence: candidate.confidence, x: px, y: py, w: pw, h: ph))
}

// 1. Text Merging: Horizontal baseline grouping (Glue currency symbols '₫', 'đ', and words on same line)
var mergedTexts: [RawText] = []
let sortedRawTexts = rawTexts.sorted {
    if abs($0.y - $1.y) > 7.0 {
        return $0.y < $1.y
    }
    return $0.x < $1.x
}

var visitedText = Array(repeating: false, count: sortedRawTexts.count)
for aIdx in 0..<sortedRawTexts.count {
    if visitedText[aIdx] { continue }
    var current = sortedRawTexts[aIdx]
    visitedText[aIdx] = true
    
    for bIdx in (aIdx + 1)..<sortedRawTexts.count {
        if visitedText[bIdx] { continue }
        let next = sortedRawTexts[bIdx]
        
        let verticalOverlap = abs(current.centerY - next.centerY) <= max(7.0, current.h * 0.45)
        let horizontalGap = next.x - current.right
        
        let isCurrency = (next.text == "₫" || next.text == "đ" || next.text == "$" || next.text.lowercased() == "vnd")
        let maxAllowedGap = isCurrency ? 35.0 : max(24.0, current.h * 2.2)
        
        if verticalOverlap && horizontalGap >= -5.0 && horizontalGap <= maxAllowedGap {
            let newX = min(current.x, next.x)
            let newY = min(current.y, next.y)
            let newRight = max(current.right, next.right)
            let newBottom = max(current.bottom, next.bottom)
            
            let sep = (current.text.hasSuffix(" ") || next.text.hasPrefix(" ") || isCurrency) ? " " : " "
            current.text = current.text + sep + next.text
            current.confidence = (current.confidence + next.confidence) / 2.0
            current.x = newX
            current.y = newY
            current.w = newRight - newX
            current.h = newBottom - newY
            visitedText[bIdx] = true
        }
    }
    current.text = current.text.replacingOccurrences(of: "  ", with: " ")
    mergedTexts.append(current)
}

// 2. Multi-line paragraph stitching: Merge subsequent wrapped lines of paragraphs
var finalParagraphs: [RawText] = []
var visitedPara = Array(repeating: false, count: mergedTexts.count)
for pIdx in 0..<mergedTexts.count {
    if visitedPara[pIdx] { continue }
    var para = mergedTexts[pIdx]
    visitedPara[pIdx] = true
    
    if para.text.count > 30 && !para.text.hasPrefix("http") && !para.text.contains("→") {
        for nextIdx in (pIdx + 1)..<mergedTexts.count {
            if visitedPara[nextIdx] { continue }
            let next = mergedTexts[nextIdx]
            
            let lineGap = next.y - para.bottom
            let isDirectlyBelow = lineGap >= 0 && lineGap <= max(14.0, para.h * 0.8)
            let leftAligned = abs(para.x - next.x) <= 30.0
            
            if isDirectlyBelow && leftAligned && next.text.count < 60 && !next.text.hasPrefix("http") && !next.text.contains("→") {
                para.text = para.text + " " + next.text
                para.w = max(para.w, next.right - para.x)
                para.h = next.bottom - para.y
                visitedPara[nextIdx] = true
                break
            }
        }
    }
    finalParagraphs.append(para)
}

// Extract Candidate Rectangles (Buttons, Input Bars)
var candidateRects: [RawRect] = []
for r in rectReq.results ?? [] {
    let b = r.boundingBox
    let px = Double(b.origin.x) * imgWidth
    let py = Double(1.0 - b.origin.y - b.size.height) * imgHeight
    let pw = Double(b.size.width) * imgWidth
    let ph = Double(b.size.height) * imgHeight
    
    if pw >= imgWidth * 0.96 && ph >= imgHeight * 0.96 { continue }
    if pw < 30 || ph < 20 { continue }
    if pw / ph > 30.0 || ph / pw > 20.0 { continue }
    
    candidateRects.append(RawRect(x: px, y: py, w: pw, h: ph, confidence: r.confidence))
}

// MARK: - Semantic UI Element Synthesis

var elements: [UIElement] = []
var usedTextIndices = Set<Int>()
var usedRectIndices = Set<Int>()

// Action button triggers
let buttonKeywords = [
    "rút tiền", "sao chép", "copy", "xác nhận", "submit", "confirm", "lưu", "save",
    "gửi", "send", "mua ngay", "buy now", "rút ngay", "đăng nhập", "login",
    "đăng ký", "sign up", "sign in", "tiếp tục", "next", "hủy", "cancel", "tải", "download"
]
let linkKeywords = [
    "tạo link", "xem chi tiết", "tìm hiểu thêm", "chính sách", "điều khoản", "trợ giúp"
]
let urlIndicators = ["http://", "https://", "www.", ".com", ".vn", "t.me"]

// Sort candidate rectangles ascending by area so inner button frames match before outer card containers
let sortedRectIndices = candidateRects.indices.sorted { candidateRects[$0].area < candidateRects[$1].area }

// Pass 1: Correlate Button & Input Containers with Text
for rIdx in sortedRectIndices {
    let r = candidateRects[rIdx]
    guard r.h >= 20 && r.h <= 70 && r.w >= 35 && r.w <= 700 else { continue }
    
    var matchingTexts: [(Int, RawText)] = []
    for (tIdx, t) in finalParagraphs.enumerated() {
        if usedTextIndices.contains(tIdx) { continue }
        
        // Rectangle must be large enough to contain the text
        if t.w > r.w * 1.30 { continue }
        
        let margin = 5.0
        let inX = t.centerX >= (r.x - margin) && t.centerX <= (r.right + margin)
        let inY = t.centerY >= (r.y - margin) && t.centerY <= (r.bottom + margin)
        
        if inX && inY {
            matchingTexts.append((tIdx, t))
        }
    }
    
    if !matchingTexts.isEmpty {
        let mergedLabel = matchingTexts.map { $0.1.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = mergedLabel.lowercased()
        let avgConf = matchingTexts.reduce(0.0) { $0 + Double($1.1.confidence) } / Double(matchingTexts.count)
        
        var elemType = "text"
        let isShortAction = mergedLabel.count <= 35
        let containsAction = buttonKeywords.contains { kw in
            if kw == "lưu" {
                return (lower == "lưu" || lower.hasPrefix("lưu ") || lower.contains(" lưu ")) && isShortAction && !lower.contains("lưu cookie") && !lower.contains("lưu ý")
            }
            return lower.contains(kw)
        }
        
        if urlIndicators.contains(where: { lower.contains($0) }) || (r.w >= 280 && r.h <= 55 && (lower.contains("nhập") || lower.contains("enter"))) {
            elemType = "input"
        } else if isShortAction && containsAction {
            elemType = "button"
        } else if isShortAction && (linkKeywords.contains(where: { lower.contains($0) }) || lower.contains("→")) {
            elemType = "button" // Action links function as buttons
        }
        
        // Only claim rectangle if it's a real interactive element (button or input)
        // If it's pure text inside a card border, let it be categorized naturally as text below
        if elemType == "button" || elemType == "input" {
            for item in matchingTexts {
                usedTextIndices.insert(item.0)
            }
            usedRectIndices.insert(rIdx)
            
            let cx = Int(r.centerX)
            let cy = Int(r.centerY)
            let elem = UIElement(
                id: "",
                type: elemType,
                text: mergedLabel,
                confidence: round2(avgConf),
                bbox: ElementBBox(x: Int(r.x), y: Int(r.y), w: Int(r.w), h: Int(r.h)),
                center: Point2D(x: cx, y: cy),
                normalized: NormalizedBox(
                    x: round4(r.x / imgWidth),
                    y: round4(r.y / imgHeight),
                    w: round4(r.w / imgWidth),
                    h: round4(r.h / imgHeight)
                )
            )
            elements.append(elem)
        }
    }
}

// Pass 2: Remaining Meaningful Text Elements
for (tIdx, t) in finalParagraphs.enumerated() {
    if usedTextIndices.contains(tIdx) { continue }
    
    let lower = t.text.lowercased()
    var elemType = "text"
    
    let isShort = t.text.count <= 35
    let containsAction = buttonKeywords.contains { kw in
        if kw == "lưu" {
            return (lower == "lưu" || lower.hasPrefix("lưu ") || lower.contains(" lưu ")) && isShort && !lower.contains("lưu cookie") && !lower.contains("lưu ý")
        }
        return lower.contains(kw)
    }
    
    if urlIndicators.contains(where: { lower.contains($0) }) {
        elemType = "input"
    } else if isShort && containsAction {
        elemType = "button"
    } else if isShort && (linkKeywords.contains(where: { lower.contains($0) }) || lower.contains("→")) {
        elemType = "button"
    }
    
    let cx = Int(t.centerX)
    let cy = Int(t.centerY)
    
    let padX = 4.0
    let padY = 3.0
    let bx = max(0, t.x - padX)
    let by = max(0, t.y - padY)
    let bw = min(imgWidth - bx, t.w + padX * 2.0)
    let bh = min(imgHeight - by, t.h + padY * 2.0)
    
    let elem = UIElement(
        id: "",
        type: elemType,
        text: t.text,
        confidence: round2(Double(t.confidence)),
        bbox: ElementBBox(x: Int(bx), y: Int(by), w: Int(bw), h: Int(bh)),
        center: Point2D(x: cx, y: cy),
        normalized: NormalizedBox(
            x: round4(bx / imgWidth),
            y: round4(by / imgHeight),
            w: round4(bw / imgWidth),
            h: round4(bh / imgHeight)
        )
    )
    elements.append(elem)
}

// Pass 3: Clean Deduplication (IoU > 0.50 -> keep best)
var deduplicated: [UIElement] = []
for elem in elements {
    var isDup = false
    for existing in deduplicated {
        let iou = computeIoU(b1: elem.bbox, b2: existing.bbox)
        if iou > 0.50 {
            isDup = true
            break
        }
    }
    if !isDup {
        deduplicated.append(elem)
    }
}

// Sort top-to-bottom, left-to-right and assign IDs
deduplicated.sort {
    if abs($0.bbox.y - $1.bbox.y) > 12 {
        return $0.bbox.y < $1.bbox.y
    }
    return $0.bbox.x < $1.bbox.x
}

var finalElements: [UIElement] = []
for (idx, elem) in deduplicated.enumerated() {
    var item = elem
    item.id = "ui_\(idx + 1)"
    finalElements.append(item)
}

// Filter by requested type
var outputElements = finalElements
if typeFilter != "all" {
    outputElements = finalElements.filter { $0.type.lowercased() == typeFilter }
}

// MARK: - Visual Debug Annotation Function

func renderDebugImage(sourceURL: URL, elements: [UIElement], highlightTarget: UIElement?, outputPath: String) {
    guard let nsImage = NSImage(contentsOf: sourceURL) else { return }
    guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    
    let w = cgImage.width
    let h = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return }
    
    // Draw base screenshot
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
    
    for elem in elements {
        let isTarget = (highlightTarget?.id == elem.id)
        let hasTargetFocus = (highlightTarget != nil)
        
        let rect = CGRect(
            x: elem.bbox.x,
            y: h - elem.bbox.y - elem.bbox.h,
            width: elem.bbox.w,
            height: elem.bbox.h
        )
        
        ctx.saveGState()
        
        if isTarget {
            // Prominent Highlight for Search Target
            ctx.setLineWidth(4.0)
            ctx.setStrokeColor(red: 1.0, green: 0.08, blue: 0.25, alpha: 1.0) // Crimson #FF1744
            ctx.setFillColor(red: 1.0, green: 0.08, blue: 0.25, alpha: 0.35)
            ctx.fill(rect)
            ctx.stroke(rect)
            
            // Draw Bullseye Target Marker at exact click center
            let clickY = CGFloat(h - elem.center.y)
            let clickX = CGFloat(elem.center.x)
            
            ctx.setLineWidth(2.0)
            ctx.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            ctx.strokeEllipse(in: CGRect(x: clickX - 9, y: clickY - 9, width: 18, height: 18))
            
            ctx.setFillColor(red: 1.0, green: 0.1, blue: 0.25, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: clickX - 4.5, y: clickY - 4.5, width: 9, height: 9))
            
            ctx.restoreGState()
            continue
        }
        
        // Non-target elements
        let alphaScale: CGFloat = hasTargetFocus ? 0.30 : 1.0
        ctx.setLineWidth(hasTargetFocus ? 1.0 : 1.8)
        
        switch elem.type {
        case "button":
            ctx.setStrokeColor(red: 0.0, green: 0.9, blue: 0.46, alpha: 1.0 * alphaScale)
            ctx.setFillColor(red: 0.0, green: 0.9, blue: 0.46, alpha: 0.14 * alphaScale)
        case "input":
            ctx.setStrokeColor(red: 0.0, green: 0.69, blue: 1.0, alpha: 1.0 * alphaScale)
            ctx.setFillColor(red: 0.0, green: 0.69, blue: 1.0, alpha: 0.14 * alphaScale)
        default:
            ctx.setStrokeColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.85 * alphaScale)
            ctx.setFillColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.08 * alphaScale)
        }
        
        ctx.fill(rect)
        ctx.stroke(rect)
        
        // Clean Corner Brackets
        let bracketLen: CGFloat = min(6.0, CGFloat(min(elem.bbox.w, elem.bbox.h)) * 0.25)
        ctx.setLineWidth(hasTargetFocus ? 1.5 : 2.2)
        ctx.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85 * alphaScale)
        
        ctx.strokeLineSegments(between: [
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX + bracketLen, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - bracketLen),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX - bracketLen, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY - bracketLen),
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + bracketLen, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX, y: rect.minY + bracketLen),
            CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX - bracketLen, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + bracketLen)
        ])
        
        if showCrosshairs {
            let clickY = CGFloat(h - elem.center.y)
            let clickX = CGFloat(elem.center.x)
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9 * alphaScale)
            ctx.fillEllipse(in: CGRect(x: clickX - 2.0, y: clickY - 2.0, width: 4.0, height: 4.0))
        }
        
        ctx.restoreGState()
    }
    
    if let finalCGImage = ctx.makeImage() {
        let destURL = URL(fileURLWithPath: outputPath)
        if let dest = CGImageDestinationCreateWithURL(destURL as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, finalCGImage, nil)
            CGImageDestinationFinalize(dest)
        }
    }
}

// MARK: - Target Search Mode

if let target = targetQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !target.isEmpty {
    let lowerTarget = target.lowercased()
    var bestMatch: UIElement? = nil
    var bestScore = -1
    
    for elem in finalElements {
        let lowerText = elem.text.lowercased()
        if lowerText.isEmpty { continue }
        
        var score = 0
        if lowerText == lowerTarget {
            score = 100
        } else if lowerText.hasPrefix(lowerTarget) {
            score = 80
        } else if lowerText.contains(lowerTarget) {
            score = 60
        } else {
            let targetWords = Set(lowerTarget.components(separatedBy: .whitespaces))
            let textWords = Set(lowerText.components(separatedBy: .whitespaces))
            let common = targetWords.intersection(textWords)
            if !common.isEmpty {
                score = 30 + common.count * 15
            }
        }
        
        if score > 0 && elem.type == "button" {
            score += 15
        }
        
        if score > bestScore {
            bestScore = score
            bestMatch = elem
        }
    }
    
    let matchResult = TargetMatchResult(
        matched: bestMatch != nil,
        target: target,
        element: bestMatch,
        click: bestMatch?.center,
        executionMs: elapsedMs
    )
    
    if let outPath = drawOutputPath {
        renderDebugImage(sourceURL: inputURL, elements: finalElements, highlightTarget: bestMatch, outputPath: outPath)
    }
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(matchResult), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
    exit(bestMatch != nil ? 0 : 1)
}

// MARK: - Normal Output Mode

let result = UIResult(
    image: ImageMetadata(path: imagePath, width: Int(imgWidth), height: Int(imgHeight)),
    executionMs: elapsedMs,
    totalCount: outputElements.count,
    elements: outputElements
)

if let outPath = drawOutputPath {
    renderDebugImage(sourceURL: inputURL, elements: outputElements, highlightTarget: nil, outputPath: outPath)
}

if isSummary {
    print("========================================================================================")
    print("🍏 APPLE NATIVE UI ELEMENT DETECTOR (Neural Engine / Vision Core)")
    print("========================================================================================")
    print("Image: \(imagePath) (\(Int(imgWidth))x\(Int(imgHeight)) px)")
    print("Speed: \(elapsedMs) ms (0 Tokens AI, 100% Offline)")
    print("Elements Detected: \(outputElements.count) [Filter: \(typeFilter)]")
    print("----------------------------------------------------------------------------------------")
    let header = "\(pad("ID", 8)) | \(pad("TYPE", 8)) | \(pad("CLICK (X,Y)", 14)) | \(pad("BBOX [X,Y,W,H]", 18)) | TEXT / LABEL"
    print(header)
    print("----------------------------------------------------------------------------------------")
    for elem in outputElements {
        let centerStr = "(\(elem.center.x), \(elem.center.y))"
        let boxStr = "[\(elem.bbox.x),\(elem.bbox.y),\(elem.bbox.w),\(elem.bbox.h)]"
        let previewText = elem.text.count > 42 ? String(elem.text.prefix(39)) + "..." : elem.text
        let line = "\(pad(elem.id, 8)) | \(pad(elem.type.uppercased(), 8)) | \(pad(centerStr, 14)) | \(pad(boxStr, 18)) | \(previewText)"
        print(line)
    }
    print("========================================================================================")
} else {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(result), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}
