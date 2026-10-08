#!/usr/bin/env python3
"""
test_macos.py: Smoke & benchmark test runner for the os-native macOS suite.
Part of the Zero-Token Native OS Superpower Suite.

Pure Python 3 stdlib. Generates its own fixtures (PDF, PNG, DOCX, speech audio, video) in a temp
directory, runs every native tool against them, asserts exit codes and output content, and
measures latency.

Usage:
  python3 tests/test_macos.py                       Run all safe tests
  python3 tests/test_macos.py -k embed -k sound     Run tests whose name contains a substring
  python3 tests/test_macos.py --bench 5             Repeat each test 5x, report median/p95 latency
  python3 tests/test_macos.py --with-side-effects   Also test clipboard, keychain, notify, screenshot
  python3 tests/test_macos.py --json report.json    Write a machine-readable report
  python3 tests/test_macos.py --list                List tests

Exit code: 0 if no test failed (skips are allowed), 1 otherwise.
"""

import argparse
import json
import os
import platform
import shutil
import statistics
import struct
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), ".."))
MAC_BIN = os.path.join(ROOT, "macos", "bin")
MAC_SRC = os.path.join(ROOT, "macos", "src")
FIXTURE_TEXT = "OS NATIVE ZERO TOKEN"
NEW_TOOLS_V27 = ["apple-sound-classify", "apple-embed", "apple-ocr-json", "apple-video-frames", "apple-video-transcode"]


class Skip(Exception):
    pass


class TestFailure(Exception):
    pass


def check(cond, msg):
    if not cond:
        raise TestFailure(msg)


# ----------------------------------------------------------------------------------------------
# Fixtures
# ----------------------------------------------------------------------------------------------

def write_pdf(path, lines):
    """Write a minimal valid single-page PDF (Helvetica text) without external libraries."""
    # Opaque white page first: rasterizers (sips) otherwise keep a transparent background that Vision can't read.
    ops = ["1 1 1 rg", "0 0 612 792 re f", "0 0 0 rg", "BT", "/F1 40 Tf", "60 680 Td"]
    for i, line in enumerate(lines):
        if i:
            ops.append("0 -70 Td")
        escaped = line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        ops.append(f"({escaped}) Tj")
    ops.append("ET")
    stream = "\n".join(ops).encode("latin-1")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
        b"/Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for num, body in enumerate(objects, 1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % num + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objects) + 1, xref)
    with open(path, "wb") as f:
        f.write(out)


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    check(head[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG")
    return struct.unpack(">II", head[16:24])


def pick_voice():
    try:
        out = subprocess.run(["say", "-v", "?"], capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return None
    voices = [line.split()[0] for line in out.splitlines() if line.strip()]
    for preferred in ("Samantha", "Daniel", "Alex", "Linh"):
        if preferred in voices:
            return preferred
    return voices[0] if voices else None


class Fixtures:
    def __init__(self, workdir):
        self.dir = workdir
        self.pdf = os.path.join(workdir, "fixture.pdf")
        self.png = os.path.join(workdir, "fixture.png")
        self.txt = os.path.join(workdir, "fixture.txt")
        self.docx = os.path.join(workdir, "fixture.docx")
        self.speech = os.path.join(workdir, "speech.aiff")
        self.video = os.path.join(workdir, "video.mp4")
        self.voice = pick_voice()
        self.errors = {}

        write_pdf(self.pdf, [FIXTURE_TEXT, "Hello World 2026"])
        with open(self.txt, "w") as f:
            f.write(f"{FIXTURE_TEXT}\nHello World 2026\n")
        self._make("png", ["sips", "-s", "format", "png", self.pdf, "--out", self.png], self.png)
        self._make("docx", ["textutil", "-convert", "docx", self.txt, "-output", self.docx], self.docx)
        say = ["say", "-o", self.speech]
        if self.voice:
            say[1:1] = ["-v", self.voice]
        self._make("speech", say + ["Hello world. This is a test of the native sound classifier."], self.speech)
        if shutil.which("ffmpeg"):
            self._make("video", ["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi",
                                 "-i", "testsrc=duration=2:size=320x240:rate=15",
                                 "-pix_fmt", "yuv420p", self.video], self.video)
        else:
            self.errors["video"] = "ffmpeg not installed"

    def _make(self, name, cmd, path):
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if res.returncode != 0 or not os.path.isfile(path):
                self.errors[name] = (res.stderr or res.stdout).strip()[:200] or f"exit {res.returncode}"
        except Exception as e:
            self.errors[name] = str(e)

    def need(self, *names):
        for n in names:
            if n in self.errors:
                raise Skip(f"fixture '{n}' unavailable: {self.errors[n]}")

    def path(self, name):
        return os.path.join(self.dir, name)


# ----------------------------------------------------------------------------------------------
# Runner
# ----------------------------------------------------------------------------------------------

class Context:
    def __init__(self, fixtures, timeout, verbose):
        self.fx = fixtures
        self.timeout = timeout
        self.verbose = verbose
        self.elapsed = 0.0

    def run(self, argv, expect_rc=0, input_text=None):
        """Run a command, account its wall time, and assert on its exit code (None = don't care)."""
        if argv[0].startswith(("apple-", "os-native")):
            base = os.path.join(ROOT, "bin") if argv[0].startswith("os-native") else MAC_BIN
            exe = os.path.join(base, argv[0])
            if not os.path.isfile(exe):
                raise TestFailure(f"{argv[0]} not found at {os.path.relpath(exe, ROOT)}")
            argv = [exe] + list(argv[1:])
        t0 = time.perf_counter()
        try:
            res = subprocess.run(argv, capture_output=True, text=True, timeout=self.timeout, input=input_text)
        except subprocess.TimeoutExpired:
            raise TestFailure(f"timed out after {self.timeout}s: {os.path.basename(argv[0])}")
        self.elapsed += time.perf_counter() - t0
        if self.verbose:
            print(f"    $ {' '.join(os.path.basename(a) if i == 0 else a for i, a in enumerate(argv))} -> {res.returncode}")
        if expect_rc is not None and res.returncode != expect_rc:
            detail = (res.stderr or res.stdout).strip().splitlines()
            raise TestFailure(f"exit {res.returncode} (expected {expect_rc}): {detail[-1] if detail else ''}"[:220])
        return res

    def json(self, argv, **kw):
        res = self.run(argv, **kw)
        try:
            return json.loads(res.stdout)
        except json.JSONDecodeError as e:
            raise TestFailure(f"invalid JSON from {argv[0]}: {e}")


TESTS = []


def test(name, category, side_effect=False, requires=()):
    def deco(fn):
        TESTS.append({"name": name, "category": category, "fn": fn,
                      "side_effect": side_effect, "requires": list(requires)})
        return fn
    return deco


# ----------------------------------------------------------------------------------------------
# Suite integrity
# ----------------------------------------------------------------------------------------------

@test("suite.build_list_matches_sources", "suite")
def _(c):
    res = c.run([os.path.join(ROOT, "macos", "build.sh"), "--list"])
    listed = set(res.stdout.split())
    expected = {os.path.splitext(f)[0].replace("_", "-") for f in os.listdir(MAC_SRC) if f.endswith(".swift")}
    check(listed == expected, f"build.sh --list {sorted(listed)} != sources {sorted(expected)}")
    missing = [t for t in sorted(listed) if not os.access(os.path.join(MAC_BIN, t), os.X_OK)]
    check(not missing, f"sources without executable binary (run macos/build.sh): {missing}")


@test("suite.build_rejects_unknown_tool", "suite")
def _(c):
    res = c.run([os.path.join(ROOT, "macos", "build.sh"), "no-such-tool"], expect_rc=2)
    check("no Swift source" in res.stderr, "missing error message")


@test("suite.init_catalog_covers_all_binaries", "suite")
def _(c):
    res = c.run(["os-native-init", "--json"])
    inv = json.loads(res.stdout[res.stdout.index("{"):])
    tools = inv.get("native_tools", {})
    on_disk = {f for f in os.listdir(MAC_BIN) if not f.startswith(".")}
    check(not inv.get("uncataloged_tools"), f"uncataloged tools: {inv.get('uncataloged_tools')}")
    check(on_disk <= set(tools), f"binaries missing from catalog: {sorted(on_disk - set(tools))}")
    for t in NEW_TOOLS_V27:
        check(t in tools, f"{t} missing from os-native-init catalog")
    bad = {t: e["status"] for t, e in tools.items() if e["status"] in ("missing", "not-executable")}
    check(not bad, f"unusable tools: {bad}")


@test("suite.router_help_lists_commands", "suite")
def _(c):
    out = c.run(["os-native", "--help"]).stdout
    for cmd in ("ocr", "search", "pdf", "sound-classify", "embed", "tts", "telemetry"):
        check(f"  {cmd} " in out, f"'{cmd}' missing from os-native --help")


@test("suite.router_unknown_command_fails", "suite")
def _(c):
    c.run(["os-native", "definitely-not-a-command"], expect_rc=1)


# ----------------------------------------------------------------------------------------------
# Language
# ----------------------------------------------------------------------------------------------

@test("embed.dimension", "language")
def _(c):
    check(c.run(["apple-embed", "--dim"]).stdout.strip() == "512", "expected 512")


@test("embed.vector_json", "language")
def _(c):
    data = c.json(["apple-embed", "Zero-token native embeddings on Apple Silicon"])
    vec = data.get("vector")
    check(isinstance(vec, list) and len(vec) == 512, f"expected 512-dim vector, got {len(vec or [])}")
    check(any(abs(v) > 1e-6 for v in vec), "vector is all zeros")


@test("embed.raw_output", "language")
def _(c):
    vals = c.run(["apple-embed", "--raw", "hello world"]).stdout.split()
    check(len(vals) == 512, f"expected 512 numbers, got {len(vals)}")
    [float(v) for v in vals]


@test("embed.cosine_ranks_semantics", "language")
def _(c):
    anchor = "a cat is sleeping on the sofa"
    near = c.json(["apple-embed", "--cosine", anchor, "a kitten naps on the couch"])["cosine_similarity"]
    far = c.json(["apple-embed", "--cosine", anchor, "quarterly corporate tax revenue report"])["cosine_similarity"]
    check(near > far, f"similar pair {near} should outrank unrelated pair {far}")


@test("embed.no_args_usage", "language")
def _(c):
    check("Usage" in c.run(["apple-embed"], expect_rc=1).stdout, "usage not printed")


@test("semantic.word_distance", "language")
def _(c):
    out = c.run(["apple-semantic", "--dist", "cat", "dog"]).stdout
    dist = float(out.split(":")[-1].split()[0])
    check(0.0 <= dist <= 2.0, f"distance out of range: {dist}")


@test("semantic.neighbors", "language")
def _(c):
    out = c.run(["apple-semantic", "--neighbors", "king", "5"]).stdout
    check(out.strip(), "no neighbors returned")


# ----------------------------------------------------------------------------------------------
# Audio
# ----------------------------------------------------------------------------------------------

@test("tts.synthesize_m4a", "audio", requires=["say"])
def _(c):
    if not c.fx.voice:
        raise Skip("no speech voices installed")
    out = c.fx.path("tts.m4a")
    c.run(["apple-tts", "Zero token speech synthesis", out, c.fx.voice])
    check(os.path.getsize(out) > 1000, "audio file too small")


@test("tts.no_args_usage", "audio")
def _(c):
    c.run(["apple-tts"], expect_rc=1)


@test("audio_convert.aiff_to_wav", "audio", requires=["afconvert"])
def _(c):
    c.fx.need("speech")
    out = c.fx.path("speech.wav")
    c.run(["apple-audio-convert", c.fx.speech, out])
    with open(out, "rb") as f:
        head = f.read(12)
    check(head[:4] == b"RIFF" and head[8:12] == b"WAVE", "output is not a WAVE file")


@test("audio_convert.aiff_to_m4a", "audio", requires=["afconvert"])
def _(c):
    c.fx.need("speech")
    out = c.fx.path("speech.m4a")
    c.run(["apple-audio-convert", c.fx.speech, out])
    with open(out, "rb") as f:
        check(f.read(12)[4:8] == b"ftyp", "output is not an MPEG-4 container")


@test("audio_convert.no_args_usage", "audio")
def _(c):
    c.run(["apple-audio-convert"], expect_rc=1)


@test("sound_classify.detects_speech", "audio")
def _(c):
    c.fx.need("speech")
    data = c.json(["apple-sound-classify", c.fx.speech, "--json", "--top", "3"])
    top = data.get("top_classifications") or []
    check(top, "no classifications returned")
    check(top[0]["category"] == "speech", f"expected 'speech' first, got {top[0]['category']}")
    check(top[0]["confidence"] >= 0.5, f"low speech confidence {top[0]['confidence']}")


@test("sound_classify.timeline", "audio")
def _(c):
    c.fx.need("speech")
    data = c.json(["apple-sound-classify", c.fx.speech, "--json", "--timeline", "--window", "0.5"])
    check(data.get("window_count", 0) >= 2, f"expected multiple windows, got {data.get('window_count')}")


@test("sound_classify.missing_file", "audio")
def _(c):
    res = c.run(["apple-sound-classify", c.fx.path("does-not-exist.wav")], expect_rc=1)
    check("not found" in (res.stderr + res.stdout).lower(), "missing 'not found' error")


@test("sound_classify.version", "audio")
def _(c):
    check("version" in c.run(["apple-sound-classify", "--version"]).stdout, "no version string")


# ----------------------------------------------------------------------------------------------
# Documents
# ----------------------------------------------------------------------------------------------

@test("docx.extract_stdout", "document", requires=["textutil"])
def _(c):
    c.fx.need("docx")
    check(FIXTURE_TEXT in c.run(["apple-docx", c.fx.docx]).stdout, "fixture text not extracted")


@test("docx.extract_to_file", "document", requires=["textutil"])
def _(c):
    c.fx.need("docx")
    out = c.fx.path("docx_out.txt")
    c.run(["apple-docx", c.fx.docx, out])
    with open(out) as f:
        check(FIXTURE_TEXT in f.read(), "fixture text not in output file")


@test("pdf_extract.text", "document")
def _(c):
    out = c.run(["apple-pdf-extract", c.fx.pdf]).stdout
    check(FIXTURE_TEXT in out and "Hello World 2026" in out, f"unexpected text: {out.strip()[:80]!r}")


@test("pdf_extract.page_number", "document")
def _(c):
    check(FIXTURE_TEXT in c.run(["apple-pdf-extract", c.fx.pdf, "1"]).stdout, "page 1 text missing")


@test("pdf_render.png_pages", "document")
def _(c):
    out_dir = c.fx.path("pdf_render")
    os.makedirs(out_dir, exist_ok=True)
    c.run(["apple-pdf-render", c.fx.pdf, out_dir, "1.0"])
    pngs = [f for f in os.listdir(out_dir) if f.lower().endswith(".png")]
    check(len(pngs) == 1, f"expected 1 rendered page, got {pngs}")
    w, h = png_size(os.path.join(out_dir, pngs[0]))
    check(w > 0 and h > 0, "empty render")


# ----------------------------------------------------------------------------------------------
# Vision
# ----------------------------------------------------------------------------------------------

@test("ocr.plain_text", "vision")
def _(c):
    c.fx.need("png")
    out = c.run(["apple-ocr", c.fx.png]).stdout.upper()
    check("ZERO TOKEN" in out, f"OCR missed fixture text: {out.strip()[:80]!r}")


@test("ocr_json.boxes", "vision")
def _(c):
    c.fx.need("png")
    items = c.json(["apple-ocr-json", c.fx.png])
    check(isinstance(items, list) and items, "no OCR items")
    hit = [i for i in items if "TOKEN" in i["text"].upper()]
    check(hit, "fixture text not found in OCR JSON")
    box = hit[0]["box"]
    check(all(0.0 <= box[k] <= 1.0 for k in ("x", "y", "width", "height")), f"box not normalized: {box}")


@test("ocr_json.missing_file_empty", "vision")
def _(c):
    check(c.run(["apple-ocr-json", c.fx.path("nope.png")]).stdout.strip() == "[]", "expected []")


@test("ui_detect.elements_json", "vision")
def _(c):
    c.fx.need("png")
    data = c.json(["apple-ui-detect", c.fx.png])
    check(isinstance(data, dict) and data.get("elements"), "no UI elements detected")


@test("ui_detect.target_search", "vision")
def _(c):
    c.fx.need("png")
    res = c.run(["apple-ui-detect", c.fx.png, "--target", "TOKEN"])
    check("TOKEN" in res.stdout.upper(), "target not found in output")


@test("classify.image", "vision")
def _(c):
    c.fx.need("png")
    check(c.run(["apple-classify", c.fx.png]).stdout.strip(), "no classification output")


@test("barcode.no_code_ok", "vision")
def _(c):
    c.fx.need("png")
    c.run(["apple-barcode", c.fx.png])


@test("face_detect.no_face_ok", "vision")
def _(c):
    c.fx.need("png")
    c.run(["apple-face-detect", c.fx.png])


@test("hand_pose.no_hand_ok", "vision")
def _(c):
    c.fx.need("png")
    c.run(["apple-hand-pose", c.fx.png])


@test("body_pose.no_body_ok", "vision")
def _(c):
    c.fx.need("png")
    c.run(["apple-body-pose", c.fx.png])


@test("bg_remove.runs", "vision")
def _(c):
    c.fx.need("png")
    # A text-only fixture has no salient subject; the tool must handle that without crashing.
    res = c.run(["apple-bg-remove", c.fx.png, c.fx.path("cutout.png")], expect_rc=None)
    check(res.returncode in (0, 1), f"crashed with exit {res.returncode}")


# ----------------------------------------------------------------------------------------------
# Media
# ----------------------------------------------------------------------------------------------

@test("img_resize.max_dimension", "media", requires=["sips"])
def _(c):
    c.fx.need("png")
    out = c.fx.path("small.png")
    c.run(["apple-img-resize", c.fx.png, "128", out])
    w, h = png_size(out)
    check(max(w, h) == 128, f"expected max side 128, got {w}x{h}")


@test("meta.file_attributes", "media", requires=["mdls"])
def _(c):
    c.run(["apple-meta", c.fx.pdf])


@test("video_frames.extract_json", "media")
def _(c):
    c.fx.need("video")
    out_dir = c.fx.path("frames/nested")
    data = c.json(["apple-video-frames", c.fx.video, "--count", "2", "--out-dir", out_dir, "--json"])
    check(data["frameCount"] == 2, f"expected 2 frames, got {data['frameCount']}")
    for fr in data["frames"]:
        check(os.path.isfile(fr["filePath"]), f"frame file missing: {fr['filePath']}")


@test("video_frames.analyze", "media")
def _(c):
    c.fx.need("video")
    data = c.json(["apple-video-frames", c.fx.video, "--count", "1", "--out-dir", c.fx.path("frames_an"),
                   "--analyze", "--json"])
    check(data["frames"] and "classifications" in data["frames"][0], "no Vision analysis in frame")


@test("video_trim.segment", "media", requires=["avconvert"])
def _(c):
    c.fx.need("video")
    out = c.fx.path("trim.mov")
    c.run(["apple-video-trim", c.fx.video, "1", out])
    check(os.path.getsize(out) > 0, "empty trimmed video")


@test("video_transcode.h264", "media", requires=["ffmpeg", "ffprobe"])
def _(c):
    c.fx.need("video")
    out = c.fx.path("transcode.mp4")
    c.run(["apple-video-transcode", c.fx.video, out, "--codec", "h264", "--quiet"])
    check(os.path.getsize(out) > 0, "empty transcoded video")


# ----------------------------------------------------------------------------------------------
# System
# ----------------------------------------------------------------------------------------------

@test("telemetry.report", "system")
def _(c):
    out = c.run(["apple-telemetry"]).stdout
    for key in ("Unified Memory", "CPU Load Average", "Chip / Architecture"):
        check(key in out, f"'{key}' missing")


@test("search.spotlight_query", "system", requires=["mdfind"])
def _(c):
    c.run(["apple-search", "kMDItemFSName == 'os-native-nonexistent-*'", c.fx.dir])


@test("search.no_args_usage", "system")
def _(c):
    c.run(["apple-search"], expect_rc=1)


@test("ls.lists_directory", "system")
def _(c):
    out = c.run(["apple-ls", c.fx.dir]).stdout
    check("fixture.pdf" in out and "DOC" in out, "fixture not listed with DOC type")


@test("caffeinate.wraps_command", "system", requires=["caffeinate"])
def _(c):
    c.run(["apple-caffeinate", "true"])


@test("router.telemetry", "system")
def _(c):
    check("Unified Memory" in c.run(["os-native", "telemetry"]).stdout, "router did not reach apple-telemetry")


@test("router.embed", "system")
def _(c):
    check(c.run(["os-native", "embed", "--dim"]).stdout.strip() == "512", "router did not reach apple-embed")


@test("router.pdf_extract", "system")
def _(c):
    check(FIXTURE_TEXT in c.run(["os-native", "pdf", "extract", c.fx.pdf]).stdout, "router pdf extract failed")


# Side-effect tests (opt-in): they touch user-visible state (clipboard, Keychain, notifications, screen).

@test("clipboard.roundtrip", "system", side_effect=True, requires=["pbcopy", "pbpaste"])
def _(c):
    saved = subprocess.run(["pbpaste"], capture_output=True).stdout
    token = f"os-native-test-{uuid.uuid4().hex[:8]}"
    try:
        c.run(["apple-clipboard", "--copy", token])
        check(c.run(["apple-clipboard", "--paste"]).stdout == token, "clipboard roundtrip mismatch")
    finally:
        subprocess.run(["pbcopy"], input=saved)


@test("keychain.set_get_delete", "system", side_effect=True, requires=["security"])
def _(c):
    service, account = f"os-native-test-{uuid.uuid4().hex[:8]}", "tester"
    try:
        c.run(["apple-keychain", "set", service, account, "s3cret-value"])
        check(c.run(["apple-keychain", "get", service, account]).stdout.strip() == "s3cret-value", "secret mismatch")
    finally:
        c.run(["apple-keychain", "delete", service, account], expect_rc=None)


@test("notify.injection_safe", "system", side_effect=True, requires=["osascript"])
def _(c):
    c.run(["apple-notify", "os-native test", 'quote " & do shell script "false"'])


@test("screenshot.capture", "system", side_effect=True, requires=["screencapture"])
def _(c):
    out = c.fx.path("screen.png")
    c.run(["apple-screenshot", out, "0,0,64,64"])
    check(os.path.isfile(out), "no screenshot written (Screen Recording permission?)")


# ----------------------------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------------------------

def percentile(values, pct):
    s = sorted(values)
    return s[min(len(s) - 1, int(round(pct / 100.0 * (len(s) - 1))))]


def main():
    ap = argparse.ArgumentParser(description="os-native macOS smoke & benchmark tests")
    ap.add_argument("-k", "--filter", action="append", default=[], help="run tests whose name contains this")
    ap.add_argument("--bench", type=int, default=1, metavar="N", help="repeat each test N times")
    ap.add_argument("--with-side-effects", action="store_true", help="include clipboard/keychain/notify/screenshot")
    ap.add_argument("--json", metavar="PATH", help="write JSON report to PATH")
    ap.add_argument("--timeout", type=float, default=60.0, help="per-command timeout in seconds")
    ap.add_argument("--list", action="store_true", help="list tests and exit")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    selected = [t for t in TESTS if not args.filter or any(f in t["name"] for f in args.filter)]
    if args.list:
        for t in selected:
            print(f"{t['category']:<9} {t['name']}{'  [side-effect]' if t['side_effect'] else ''}")
        return 0

    if platform.system() != "Darwin":
        print(f"SKIP: macOS test suite requires Darwin (detected {platform.system()})")
        return 0

    bench = max(1, args.bench)
    print("=" * 78)
    print(f"os-native macOS test suite | {platform.machine()} | macOS {platform.mac_ver()[0]} | "
          f"Python {platform.python_version()}" + (f" | bench x{bench}" if bench > 1 else ""))
    print("=" * 78)

    workdir = tempfile.mkdtemp(prefix="os-native-tests-")
    t_fx = time.perf_counter()
    fx = Fixtures(workdir)
    print(f"Fixtures ready in {(time.perf_counter() - t_fx) * 1000:.0f} ms"
          + (f" (unavailable: {', '.join(sorted(fx.errors))})" if fx.errors else ""))
    print(f"{'STATUS':<6}  {'TEST':<40} {'LATENCY':>10}  DETAIL")
    print("-" * 78)

    results = []
    for t in selected:
        rec = {"name": t["name"], "category": t["category"], "status": "PASS", "detail": "", "latency_ms": []}
        missing = [r for r in t["requires"] if not shutil.which(r)]
        if t["side_effect"] and not args.with_side_effects:
            rec.update(status="SKIP", detail="side effect (use --with-side-effects)")
        elif missing:
            rec.update(status="SKIP", detail=f"missing: {', '.join(missing)}")
        else:
            for _ in range(bench):
                ctx = Context(fx, args.timeout, args.verbose)
                try:
                    t["fn"](ctx)
                except Skip as e:
                    rec.update(status="SKIP", detail=str(e))
                    break
                except TestFailure as e:
                    rec.update(status="FAIL", detail=str(e))
                    break
                except Exception as e:
                    rec.update(status="FAIL", detail=f"{type(e).__name__}: {e}")
                    break
                rec["latency_ms"].append(round(ctx.elapsed * 1000, 2))
        lat = rec["latency_ms"]
        if lat:
            rec["median_ms"] = round(statistics.median(lat), 2)
            if len(lat) > 1:
                rec["p95_ms"] = round(percentile(lat, 95), 2)
                rec["detail"] = rec["detail"] or f"min {min(lat):.1f} / p95 {rec['p95_ms']:.1f} ms"
        lat_str = f"{rec['median_ms']:.1f} ms" if lat and rec["status"] == "PASS" else "-"
        color = {"PASS": "\033[32m", "FAIL": "\033[31m", "SKIP": "\033[33m"}[rec["status"]] if sys.stdout.isatty() else ""
        reset = "\033[0m" if color else ""
        print(f"{color}{rec['status']:<6}{reset}  {t['name']:<40} {lat_str:>10}  {rec['detail']}")
        results.append(rec)

    shutil.rmtree(workdir, ignore_errors=True)

    counts = {s: sum(1 for r in results if r["status"] == s) for s in ("PASS", "FAIL", "SKIP")}
    total_ms = sum(r.get("median_ms", 0) for r in results if r["status"] == "PASS")
    print("-" * 78)
    print(f"{counts['PASS']} passed, {counts['FAIL']} failed, {counts['SKIP']} skipped "
          f"| {len(results)} tests | {total_ms / 1000:.2f}s tool time")
    by_cat = {}
    for r in results:
        if r["status"] == "PASS":
            by_cat.setdefault(r["category"], []).append(r["median_ms"])
    print("Median latency by category: " + ", ".join(
        f"{cat} {statistics.median(v):.0f} ms" for cat, v in sorted(by_cat.items())))

    if args.json:
        report = {
            "suite": "os-native-macos", "arch": platform.machine(), "macos": platform.mac_ver()[0],
            "bench_runs": bench, "summary": counts, "fixtures_unavailable": fx.errors, "results": results,
        }
        with open(args.json, "w") as f:
            json.dump(report, f, indent=2)
        print(f"JSON report written to {args.json}")

    return 1 if counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
