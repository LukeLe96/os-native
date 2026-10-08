# os-native: Architecture & Design Doctrine

## 1. Executive Summary

`os-native` is a cross-platform, zero-token system execution layer designed for autonomous AI agents (Hermes, Claude Code, Codex, Custom Autonomous Swarms). It bridges the physical host's silicon capabilities (Apple Neural Engine, DirectML, Linux POSIX C++) directly into agent runtimes, eliminating the costly anti-pattern of using frontier LLMs for primitive deterministic tasks.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        AUTONOMOUS AGENT RUNTIME                        │
│            (Hermes Agent / Claude Code / Codex / Python SDK)           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                         CLI / JSON Dispatch Call
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     UNIVERSAL ROUTER (bin/os-native)                    │
│           • Platform Auto-Detection (Darwin, Linux, Windows)           │
│           • Command Normalization & Argument Sanitization              │
│           • JSON-Structured Output Emission for Agent Parsing          │
└───────────────┬───────────────────┼────────────────────┬───────────────┘
                │                   │                    │
          macOS (Darwin)          Linux               Windows
                ▼                   ▼                    ▼
┌───────────────────────┐ ┌───────────────────┐ ┌────────────────────────┐
│     macos/bin/        │ │     linux/        │ │       windows/         │
│ • Apple Vision ANE    │ │ • Tesseract C++   │ │ • WinRT Windows.Media  │
│ • SoundAnalysis ANE   │ │ • Poppler C++     │ │ • DirectML GPU Accel   │
│ • NaturalLanguage     │ │ • OpenXML Unzip   │ │ • Windows Search OLEDB │
│ • PDFKit / TextEngine │ │ • POSIX Epoll     │ │ • System.Speech SAPI   │
│ • Media Engine (M4)   │ │ • Systemd Inhibit │ │ • Windows Toast / WMI  │
└───────────────────────┘ └───────────────────┘ └────────────────────────┘
```

---

## 2. Core Architectural Principles

### Principle 1: Zero-Token Floor (Deterministic Operations)
Deterministic data transformations—such as OCR, audio format conversion, vector distance calculation, PDF rendering, and document extraction—must **never burn frontier LLM tokens**. 
* **Legacy:** Uploading a receipt screenshot to GPT-4o costs ~$0.02 and 2,000 tokens, taking 3–5 seconds.
* **os-native:** Local Apple Vision `apple-ocr` extracts all text in **0.21 seconds at $0.00 cost** with 100% offline privacy.

### Principle 2: Hardware-First Silicon Exploitation
`os-native` binds directly to hardware co-processors:
1. **Apple Neural Engine (ANE - 38 TOPS on M4):** Offloads vision, audio classification, and speech models with 0% CPU and 0% GPU utilization.
2. **Unified Memory Architecture (UMA - 120 GB/s):** Zero-copy frame transfers between decoders, neural networks, and storage via `IOSurface` and `CVPixelBuffer`.
3. **Dedicated Media Engines:** Hardware AV1 decoder, ProRes 422/4444 accelerator, and hardware HEVC with Alpha channel encoding.

### Principle 3: Fail-Closed Security & Sanitization
Host automation tools must protect against prompt-injection and shell-injection attacks:
* **AppleScript Hardening:** All GUI and system notifications pass dynamic content via `argv` array arguments, completely eliminating script injection.
* **File System Boundaries:** Deterministic operations validate input existence, bounds, and directory structure prior to execution.
* **Local Privacy:** No telemetry, host fingerprints, or file contents are transmitted to external servers without explicit user authorization.

---

## 3. Tool Catalog & Capabilities

### macOS Suite (`macos/bin/` — 30 Native Tools)
| Domain | Tool | Engine / Framework | Latency |
| :--- | :--- | :--- | :---: |
| **Vision** | `apple-ocr` | Apple Vision (`VNRecognizeTextRequest`) | ~0.21s |
| | `apple-ocr-json` | Apple Vision with Bounding Boxes | ~0.21s |
| | `apple-ui-detect` | Apple Vision UI & Target Locator | ~0.04s–0.3s |
| | `apple-bg-remove` | Apple Vision Foreground Segmentation | ~0.24s |
| | `apple-barcode` | Apple Vision Barcode / QR Decoder | ~0.02s |
| | `apple-classify` | Apple Vision Zero-Shot Classifier | ~0.05s |
| | `apple-face-detect` | Apple Vision Landmark & Bounding Box | ~0.05s |
| | `apple-hand-pose` | Apple Vision 21-joint Hand Pose | ~0.10s |
| | `apple-body-pose` | Apple Vision 17-joint Body Pose | ~0.12s |
| **Audio** | `apple-sound-classify` | Apple SoundAnalysis (300+ classes) | ~0.095s |
| | `apple-tts` | Apple SpeechSynthesis (`say -v Linh`) | ~0.05s |
| | `apple-audio-convert` | CoreAudio `afconvert` | ~0.02s |
| **Language** | `apple-embed` | Apple NaturalLanguage (512-dim Cosine) | ~0.005s |
| | `apple-semantic` | Apple NaturalLanguage Word Embedding | ~0.04s |
| **Document** | `apple-docx` | macOS TextEngine (`textutil`) | ~0.01s |
| | `apple-pdf-extract` | Apple PDFKit Native Parser | ~0.02s |
| | `apple-pdf-render` | Apple PDFKit High-Res Rasterizer | ~0.03s/page |
| **Media** | `apple-video-trim` | AVFoundation / Media Engine | ~0.05s |
| | `apple-video-frames` | AVFoundation Keyframe Extractor | ~0.09s |
| | `apple-video-transcode`| VideoToolbox Hardware Transcoder | ~0.30s |
| | `apple-img-resize` | macOS SIPS Image Engine | ~0.01s |
| | `apple-meta` | Spotlight Engine (`mdls`) | ~0.001s |
| **System** | `apple-telemetry` | Kernel Telemetry (`vm_stat`, `sysctl`) | ~0.04s |
| | `apple-search` | Spotlight Index Engine (`mdfind`) | ~0.02s |
| | `apple-clipboard` | Universal Clipboard (`pbcopy`/`pbpaste`) | ~0.01s |
| | `apple-notify` | Native Notification Center (`osascript`) | ~0.02s |
| | `apple-keychain` | Secure Enclave Hardware Keychain | ~0.01s |
| | `apple-caffeinate` | Kernel Sleep Inhibitor | ~0.01s |
| | `apple-screenshot` | Native Window / Screen Grabber | ~0.05s |
| | `apple-ls` | Structured Directory Telemetry | ~0.03s |

---

## 4. Build System & Compilation Pipeline

All Swift-based native tools are compiled directly to ARM64 Mach-O binaries with maximum compiler optimization:

```bash
# Build all Swift native tools
./macos/build.sh --all

# Build specific tool
./macos/build.sh apple-sound-classify

# Inspect buildable targets
./macos/build.sh --list
```

### Build Specifications:
* Compiler: `/usr/bin/swiftc`
* Flags: `-O -target arm64-apple-macos14.0`
* Library Parsing: `@main` structs compiled with `-parse-as-library`; top-level procedural tools compiled without.
* Output: Placed directly in `macos/bin/` with zero runtime library dependencies.

---

## 5. Verification & Test Harness

The automated test runner (`tests/test_macos.py`) executes end-to-end integration and smoke tests against real hardware:

```bash
# Run complete test suite (safe, read-only)
python3 tests/test_macos.py

# Run with system side-effect tests (clipboard, notifications)
python3 tests/test_macos.py --with-side-effects

# Measure latency distribution
python3 tests/test_macos.py --verbose
```

**Quality Bar:** 51 passing test cases covering vision, audio, language, documents, media, and system routing with sub-second execution guarantees.
