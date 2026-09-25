---
name: mac-mini-native
description: "Use when running native Mac mini tasks (OCR, bg removal, QR, docx, PDF, poses, TTS, video trim, clipboard, notify, keychain, telemetry, Spotlight)."
version: 2.6.0
author: Tahi
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [MacMini, AppleSilicon, NeuralEngine, NativeAI, Vision, PDFKit, SIPS, Spotlight, Docx, MediaEngine, Keychain, Clipboard, Telemetry, UIDetection]
    related_skills: [os-native, os-native-init, apple-ai]
prerequisites:
  commands: [swift]
---

# Mac Mini Native AI & System Superpower Suite

Dedicated toolkit designed specifically for Apple Silicon M-series hardware and the Apple Neural Engine (ANE). Runs 100% offline, guarantees complete data privacy, executes with sub-second latency, consumes zero API tokens, and requires no bulky third-party libraries.

All 24 compiled ARM64 binaries and shell utilities reside directly in `$PATH` (`~/.hermes/bin/` and `~/.local/bin/`).

---

## Tool Catalog

### 1. Computer Vision & Neural Engine
* `apple-bg-remove <input> <output.png>`: Subject lifting / transparent PNG generation (~0.24s).
* `apple-ocr <input>`: Live Text OCR (Native Vietnamese & English support, ~0.21s).
* `apple-ui-detect <input> [--target <query>] [--type <type>] [--draw out.png]`: Native UI element & interactive target detector (~0.04s - 0.3s, zero tokens).
* `apple-barcode <input>`: QR and Barcode decoder (0.02s).
* `apple-classify <input>`: Zero-shot image classification and tagging (0.05s).
* `apple-face-detect <input>`: Facial bounding box and landmark detection (0.05s).
* `apple-hand-pose <input>`: 21-joint skeletal hand pose estimation (~0.1s).
* `apple-body-pose <input>`: 17-joint skeletal human body pose estimation (~0.12s).

### 2. Office Documents & PDFKit
* `apple-docx <input.docx> [output.txt]`: Direct Word document text extraction in 0.01s.
* `apple-pdf-extract <file.pdf> [page]`: High-speed PDF text parsing (0.02s).
* `apple-pdf-render <file.pdf> <out_dir> [scale]`: High-resolution PDF-to-PNG rendering.

### 3. Video & Media Engine
* `apple-video-trim <video> <duration> <output> [start]`: Hardware-accelerated video trimming.
* `apple-img-resize <input> <max_px> <output>`: Instant image resizing and compression via SIPS (0.01s).
* `apple-meta <file_path>`: Deep file metadata inspection via Spotlight (0.001s).

### 4. Audio & Natural Language
* `apple-tts "<text>" <out.m4a> [voice]`: Offline text-to-speech with phonetic filtering.
* `apple-audio-convert <in> <out>`: Sub-millisecond audio transcoding via CoreAudio.
* `apple-semantic --dist / --neighbors`: Vector semantic similarity via NLEmbedding.

### 5. System, Telemetry & Security
* `apple-clipboard --copy / --paste`: Universal clipboard synchronization across Apple devices.
* `apple-notify "<title>" "<msg>" [sound]`: Native desktop notification center alerts.
* `apple-keychain set|get|delete`: Secure hardware storage via Apple Keychain (Secure Enclave).
* `apple-telemetry`: Real-time Unified Memory, CPU load, and uptime telemetry.
* `apple-caffeinate <command...>`: Sleep inhibitor keeping hardware at peak performance.
* `apple-search "<query>" [dir]`: Sub-second file search via Spotlight index (`mdfind`).
* `apple-ls [dir]`: Rich directory listing replacing legacy `ls -la`.
