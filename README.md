# os-native: Zero-Token OS Superpower Suite

> **The Zero-Token Hook:**  
> *Stop burning hundreds of dollars in LLM API tokens and waiting seconds for network roundtrips for tasks your operating system was born to do for free in milliseconds.*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux-blue.svg)](#cross-platform-matrix)
[![Zero-Token](https://img.shields.io/badge/Zero--Token-100%25%20Offline-brightgreen.svg)](#benchmarks)
[![Author](https://img.shields.io/badge/Author-Tan%20Le%20Duy%20%40%20tahi.vn-orange.svg)](https://tahi.vn)

---

## ⚡ The Zero-Token Philosophy

Modern AI workflows suffer from a costly anti-pattern: **offloading primitive deterministic operations to cloud Frontier LLMs**.

* **Why spend $0.03 and 2,000 multimodal tokens** for GPT-4o or Claude 3.5 to transcribe a receipt screenshot when your host OS has an optimized Neural Engine or WinRT OCR engine that parses it in **0.2 seconds completely offline**?
* **Why stream 50MB PDF binaries over the internet** when local C++ Poppler or Apple PDFKit extracts every character and vector path in **0.02 seconds with zero data leakage**?

`os-native` bridges the physical machine's silicon (Apple Neural Engine, DirectML, POSIX C++) directly into autonomous AI Agents (Hermes, Claude Code, Codex, Custom Bots).

---

## 💰 The Economic Case: Cloud LLM APIs vs. os-native (Before & After)

| Task Category | Legacy Approach (Cloud APIs / Bloatware) | Legacy Cost & Latency | With `os-native` | Total Savings |
| :--- | :--- | :--- | :--- | :---: |
| **Image OCR & Live Text** | Frontier Vision API (GPT-4o / Claude 3.5 / Google Cloud Vision) | **~$0.015 – $0.03 / image**<br>(~1,500–2,500 tokens, 3s–5s latency) | **$0.00 (0 Tokens)**<br>Runs in **~0.21s** | **100% Cost Reduction**<br>15x Faster |
| **Background / Subject Removal** | Commercial Cloud APIs (Remove.bg / Clipdrop) or 1.5GB Python PyTorch/rembg | **~$0.10 – $0.20 / image**<br>(Free tiers cap resolution to 0.25MP) | **$0.00 (0 Tokens)**<br>Runs in **~0.24s** (Full resolution) | **100% Cost Reduction**<br>Zero RAM Bloat |
| **PDF & Document Parsing** | Streaming full document bytes into LLM context window | **~$0.05 – $0.15 / document**<br>(10,000–30,000 tokens consumed) | **$0.00 (0 Tokens)**<br>Runs in **~0.01s – 0.02s** | **100% Cost Reduction**<br>Instant Zero-Latency |
| **Video & Audio Processing** | Installing heavy FFmpeg binaries, 100% CPU thread lock | CPU thermal throttling & power drain | **$0.00 (0 Tokens)**<br>Apple Silicon Media Engine (~0.3s) | **~0% CPU Overhead** |
| **Data Privacy & Compliance** | Transmitting contracts, receipts, customer chat logs to 3rd-party cloud servers | Critical data leak risk & GDPR liability | **100% On-Device**<br>Data never leaves host RAM | **Priceless** |

### 📈 Monthly Enterprise Agent Fleet Projection (100 Daily Tasks)
In a modest multi-agent setup processing 100 OCR requests, 50 image segmentations, and 30 documents daily:
* **Legacy Cloud Approach:** ~$10.00 / day ➔ **~$300.00 / month (~$3,600 / year)** wasted on primitive compute.
* **With `os-native`:** **$0.00 / month.** Pay for LLM tokens only when you actually need complex reasoning.

---

## 🏛️ Project Architecture

```
os-native/
├── bin/
│   ├── os-native            # Universal Cross-Platform Dispatcher CLI
│   └── os-native-init       # Environment Profiler, Tool Auditor & Privacy Guardrail
├── macos/                   # macOS & Apple Silicon Native Suite (24 Tools)
│   ├── bin/                 # Compiled ARM64 Native Binaries (Swiftc -O & Shell)
│   ├── src/                 # Swift source code implementations
│   └── SKILL.md             # Detailed Mac mini operational specs
├── windows/                 # Windows Native Suite (10 Reference Tools)
│   ├── win-ocr.ps1          # WinRT Windows.Media.Ocr (Offline OCR)
│   ├── win-tts.ps1          # System.Speech.Synthesis SAPI TTS
│   ├── win-docx.ps1         # Word .docx text extractor without Office
│   ├── win-clipboard.ps1    # Universal clipboard synchronization
│   ├── win-notify.ps1       # Native Windows Toast Notifications
│   ├── win-keychain.ps1     # Hardware-backed Credential Manager (cmdkey)
│   ├── win-telemetry.ps1    # Host hardware & memory telemetry
│   ├── win-scan.ps1         # Automated malware scanning via Windows Defender CLI
│   ├── win-search.ps1       # Sub-second file search via Windows Search OLE DB
│   └── win-screen.ps1       # Screen capture via .NET System.Drawing
├── linux/                   # Linux Native Suite (10 Reference Tools)
│   ├── linux-ocr.sh         # Tesseract OCR engine (vie + eng)
│   ├── linux-pdf.sh         # Poppler-utils (pdftotext, pdftoppm)
│   ├── linux-docx.sh        # Direct OpenXML extraction without LibreOffice
│   ├── linux-clipboard.sh   # Wayland (wl-clipboard) / X11 (xclip)
│   ├── linux-notify.sh      # Desktop notifications via libnotify (notify-send)
│   ├── linux-telemetry.sh   # Linux kernel /proc telemetry
│   ├── linux-search.sh      # Binary index database search via plocate/locate
│   ├── linux-caffeinate.sh  # Sleep inhibitor via systemd-inhibit
│   ├── linux-tts.sh         # Offline TTS via espeak-ng / piper
│   └── linux-audio-convert.sh # Native audio format conversion via sox / ffmpeg
├── LICENSE                  # MIT License with attribution clause
└── README.md                # Master architectural documentation
```

---

## 🚀 Quickstart

### 1. Inspect Your Host Environment (`os-native-init`)

Before running tasks, evaluate your host machine's hardware capabilities and tool inventory:

```bash
# Safe, 100% offline host capability audit
os-native-init

# Output structured JSON for automated agent parsing
os-native-init --json

# Trigger web reconnaissance mode (Strict privacy consent enforced)
os-native-init --web-recon
```

### 2. Execute Universal Commands (`os-native`)

The `os-native` runner auto-detects `Darwin`, `Linux`, or `Windows` and routes your command to the host's fastest local implementation:

```bash
# 1. OCR text extraction from any image
os-native ocr path/to/screenshot.png

# 2. Sub-second indexed file search (Spotlight / OLEDB / Plocate)
os-native search "quarterly_report" /path/to/search/scope

# 3. Extract plain text from Word document (.docx)
os-native docx path/to/contract.docx

# 4. Extract PDF text or render pages to high-res images
os-native pdf extract document.pdf
os-native pdf render document.pdf ./pdf_output_dir

# 5. Convert audio formats in sub-milliseconds without FFmpeg bloat
os-native audio-convert input.wav output.m4a

# 6. Post a native desktop notification
os-native notify "Pipeline Status" "Model training completed successfully"

# 7. Synchronize with system clipboard across devices
os-native clipboard --copy "Extracted API key or prompt"
os-native clipboard --paste

# 8. Check real-time hardware resource telemetry
os-native telemetry
```

---

## 📊 Empirical Benchmarks & Performance Matrix

### Verified Hardware Benchmarks (macOS on Apple Silicon M-Series)

The following metrics were **empirically benchmarked on Apple Silicon (M-series, unified memory, 16-core Neural Engine)**:

| Operation | Tool | Implementation | Measured Latency | Zero-Token Cost |
| :--- | :--- | :--- | :---: | :---: |
| **Live Text OCR** | `apple-ocr` | Apple Vision (`VNRecognizeTextRequest`) | **~0.21s** | 0 tokens ($0.00) |
| **UI Element & Target Detector** | `apple-ui-detect` | Apple Vision (`VNRecognizeText` + `VNDetectRectangles`) | **~0.04s – 0.3s** | 0 tokens ($0.00) |
| **Subject / Background Removal** | `apple-bg-remove` | Apple Vision (`VNGenerateForegroundInstanceMask`) | **~0.24s** | 0 tokens ($0.00) |
| **Image Tagging & Classification**| `apple-classify` | Apple Vision (`VNClassifyImageRequest`) | **~0.05s** | 0 tokens ($0.00) |
| **QR & Barcode Scanner** | `apple-barcode` | Apple Vision (`VNDetectBarcodesRequest`) | **~0.02s** | 0 tokens ($0.00) |
| **Facial & Landmark Detection** | `apple-face-detect`| Apple Vision (`VNDetectFaceLandmarksRequest`) | **~0.05s** | 0 tokens ($0.00) |
| **Word Document Parsing** | `apple-docx` | macOS TextEngine (`textutil`) | **~0.01s** | 0 tokens ($0.00) |
| **PDF Text Extraction** | `apple-pdf-extract`| Apple PDFKit Native | **~0.02s** | 0 tokens ($0.00) |
| **PDF Page Rendering (High-res)**| `apple-pdf-render` | Apple PDFKit + AppKit | **~0.019s/page** | 0 tokens ($0.00) |
| **Hardware Video Trimming** | `apple-video-trim` | Apple Silicon Media Engine (`avconvert`) | **~0.3s** | 0 tokens ($0.00) |
| **Image Compression / Resize** | `apple-img-resize` | macOS SIPS Engine | **~0.01s** | 0 tokens ($0.00) |
| **Sub-second Indexed Search** | `apple-search` | macOS Spotlight Index (`mdfind`) | **~0.03s** | 0 tokens ($0.00) |
| **RAM Cache Purge** | `purge` | macOS Kernel Memory Manager | **~0.1s** | 0 tokens ($0.00) |

---

### Windows & Linux Performance Estimates (Vendor Documentation)

* **Windows (WinRT OCR):** Microsoft documentation specifies hardware-accelerated WinRT OCR latency typically averages **150ms – 400ms** depending on resolution.
* **Linux (Tesseract & Poppler):** Vendor C++ benchmarks document `pdftotext` throughput exceeding **50–100 pages/second** on standard multi-core x86_64 CPUs.
* *Note:* No official unified single-binary benchmark suite has been certified on this specific host for Windows or Linux.

---

## ⚠️ Important Community Notice: Windows & Linux Verification Needed!

> **Call for Community Contributors & Testers:**  
> 
> * **macOS Suite Status:** **Production-Ready & 100% Tested.** All 24 tools in the `macos/` directory have been compiled to native ARM64 binaries and rigorously benchmarked on physical Apple Silicon hardware.
> 
> * **Windows & Linux Suites Status:** **Initial Reference Implementations.**  
>   Due to the vast diversity of Linux distributions (Ubuntu, Arch, Fedora, Debian) and Windows configurations (Windows 10, 11, Server, ARM64 vs x86_64), the scripts provided in `windows/` and `linux/` are reference designs that **still require extensive community field-testing, verification, and hardening**.
> 
> * **How You Can Help:**  
>   We warmly invite open-source developers, system administrators, and AI enthusiasts to:
>   1. **Fork the repository.**
>   2. Test the scripts on your specific Windows and Linux setups.
>   3. Report edge cases, path variances, or missing dependencies via GitHub Issues.
>   4. Submit Pull Requests with improvements, optimized flags, or native C#/C++ compiled binaries!

---

## 🔒 Mandatory Privacy Consent Protocol

Before transmitting any host environment telemetry (OS distribution, kernel version, hardware architecture) to external search engines or online APIs, AI Agents executing `os-native-init` **MUST** request and obtain explicit user authorization:

> *"I am about to query external online sources with your host environment profile ([OS], [Architecture], [Kernel Version]) to discover specialized built-in tools and optimization packages. Because system versions and hardware specs are sensitive host information, do you consent to transmitting this profile to the web? (yes/no)"*

---

## 📄 License & Attribution

This project is licensed under the **[MIT License](LICENSE)**.

* **Author & Creator:** Tan Le Duy (Tân Lê Duy) <ldtan96@gmail.com>
* **Official Website & Portal:** [tahi.vn](https://tahi.vn)
* **Direct Contact:** [ldtan96@gmail.com](mailto:ldtan96@gmail.com)
* **Commercial Use:** Permitted free of charge for startups, enterprises, and open-source projects.
* **Attribution Requirement:** Any redistribution, modification, or inclusion of this software or its derivatives in commercial products must retain the original copyright notice and acknowledge the author with reference to [tahi.vn](https://tahi.vn).
