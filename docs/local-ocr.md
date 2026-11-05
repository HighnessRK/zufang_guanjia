# Xiaomi-OCR-0 Android OCR

## Distribution configuration

The default CPU AAR is bundled by llama_cpp_dart 0.9.0-dev.12's native asset
hook. `android:extractNativeLibs="true"` is required for backend discovery.
AGP 9 also requires `packaging.jniLibs.useLegacyPackaging = true`; the app
sets both, as verified by a successful arm64 Release build containing libllama,
libmtmd, libggml and the CPU backend.
Both the Q8_0 model and F16 projector are required. Files live in application
support `models/xiaomi-ocr-0/`; never in rental.db or the Feishu snapshot.

Default source (v1.2.4):
https://gitee.com/highnesssrk/xiaomi-ocr-0-gguf/releases/tag/v1.0.0 .
This is our byte-identical domestic mirror of
https://github.com/xzl01/Xiaomi-OCR-0-GGUF/releases/tag/v1.0.0
(community conversion, not a Xiaomi-operated download service).
Q8_0 uses the same 20 transport segments; the F16 projector is split into 5
segments to meet Gitee's per-attachment limit. Model bytes and filenames are
unchanged. Both upstream Apache-2.0 licenses and a per-segment SHA-256 manifest
are included in the mirror release. All 25 segments were anonymously downloaded
and their size and SHA-256 compared with the original verified files.
The 1,040,937,440-byte download is shown as 1.04 GB (decimal units), including
both files. Overall progress includes saved segments and completed models.
An old single-file projector partial is migrated into the new segment layout.
Gitee may ignore HTTP Range; in that case the current segment is streamed from
the beginning and the saved prefix discarded from the response, preserving the
local prefix and displayed progress. Completed segments are never redownloaded.
Full SHA-256 values from upstream `scripts/fetch-model.sh`:

- Main: `1b3c4e37129cb29896c61c833589be2acfb9eb0370bb84d3df12759f1f0f457a`
- Projector: `037e6a655ff168a5decb51c16dc819c06b7e19684441e98f00cb732c2ac61084`

Both assembled files are hashed before use and again at app startup. Reserve
at least 2 GB for downloads and temporary assembly. Build-time overrides remain supported with
`--dart-define=OCR_MODEL_URL=...`, `OCR_MODEL_SHA256`, `OCR_PROJECTOR_URL`,
`OCR_PROJECTOR_SHA256`; replacement files must have audited matching hashes.
No API keys belong in these settings.

The conversion repository declares Apache-2.0:
https://github.com/xzl01/Xiaomi-OCR-0-GGUF/blob/main/LICENSE .
Original model and model card: https://github.com/xiaomi-research/Xiaomi-OCR-0 .
Original safetensors are also available at
https://www.modelscope.cn/models/SeerRay-Lab/Xiaomi-OCR-0/files .
That repository currently does not supply GGUF or a standalone GGUF projector;
its `model.safetensors` cannot be passed directly to llama_cpp_dart.
Another community conversion is available at
https://www.modelscope.cn/models/prithivMLmods/Xiaomi-OCR-0-GGUF/files .
Its current listing contains BF16 and Q3/Q4/Q5/Q6 variants and a BF16 projector,
but no Q8_0 + F16 pair. It is not a byte-identical mirror of the default files;
do not mix checksums or projectors between these conversions without testing.
Weights are downloaded separately on user request, not bundled into the APK.
Review the upstream model card and license before redistributing a mirror.

## Current acceptance status

- Static analysis: clean; 103 automated tests pass (including whitelist SQLite,
  cloud/local privacy, HTTP resume/hash/retry, three-scale layout and the new
  meter-window locator/parser coverage).
- Independent device probe package: `com.zufang.guanjia.ocrprobe`, installed
  without initializing the ledger or cloud/sync services.
- Real GGUF inference: synthetic digits `24737` recognized on CPU in 5.751 s;
  public mechanical meter photo read `23355` correctly in 12.179 s.
  Fixture: https://commons.wikimedia.org/wiki/File:Compteur_electrique.jpg .
- Floor accuracy: **accepted on the private five-meter real photo**. Automatic
  detection found the five bright meter windows, sorted them top-to-bottom and
  left-to-right, cropped each digit band, suppressed the red 0.1 wheel and read
  all five values in 257.9 s on the CPU backend. The result matches the
  human-verified expected list exactly. The photo, crop files and concrete
  readings remain private and are not part of the repository or release.
  The acceptance input still starts from the original photo and every crop is
  limited to a 384 px short edge; no answer values are written into prompts,
  filenames or business code. A generic 3x2 split, whole-image 384 px, 768 px and
  1024-token attempts had all failed and were removed. The shipped path now
  falls back to whole-image recognition whenever window count or parsing does
  not match, so cloud fallback semantics stay unchanged.
- Performance note: five CPU windows take about 4-5 minutes on SM8650. This is
  accepted for the release but should not be described as real-time.
- Download management (200/206/416, bad Range, bad SHA-256, bounded resume and
  retries) is covered by automated tests. A full live download from the public
  upstream into the production package is not claimed as a separate acceptance
  pass; the installed probe uses the same verified files and hashes.
- Production version is 1.2.4+19.

## Hexagon build limitation

`hooks.user_defines.llama_cpp_dart.android_aar` selects the AAR at BUILD time:

```yaml
hooks:
  user_defines:
    llama_cpp_dart:
      android_aar: native/llama-cpp-dart-hexagon.aar
```

This app deliberately ships CPU and shows a disabled build-status checkbox.
Do not merely change a Dart boolean or claim that a detected HTP device means
model tensors are running on it. A future Hexagon distribution must explicitly
select devices, test placement with native logs, and reinitialize on CPU on
failure. The current CPU path sets gpuLayers=0 and projector useGpu=false.
SoC metadata comes from Android Build.SOC_MODEL (API31+), HARDWARE and BOARD;
unrecognized chips are not presumed supported. No NPU speedup is claimed.

## Manual acceptance tests (real device)

1. Without weights: cloud API recognition works. Selecting cloud never loads
   native models. Invalid/missing model URLs or checksums disable download.
2. With audited metadata: start download, pause, restart app, resume. Test a
   server ignoring Range (restart that file), invalid Content-Range (reject),
   disconnection and wrong hash (delete corrupt partial). Cancel clears partials.
3. Check both hashes after restart; tamper with either file and verify local
   selection is disabled. Delete disposes native inference before removing files.
4. On device, use a single clear meter photo first. Whole-image preprocessing
   caps the short edge at 384px and long edge at 1024px. Floor photos locate
   each meter window, crop the digit band and cap its short edge at 384px and
   long edge at 1536px. Both model and projector must load, supportsVision
   must be true. Verify output and native backend logs.
5. Automatic mode falls back on inference, window-count or parse failure;
   local-priority mode never uploads on failure. No model automatically falls
   back to cloud. Actual engine and fallback warning are shown in OCR settings.
6. Set Android font scale to 1.0, 1.1 and 1.25; test meter rows, bulk-entry
   sheet, settings, rooms, home, collection, reports and dialogs in both themes.
7. Exclude a room: home, reports, collection and reminders omit its charges;
   raw ledger, room counts and photo recognition remain intact. Remove exclusion
   and verify historical totals return. Test backup/restore in a disposable profile.

Automatic tests do not prove GGUF compatibility, hardware acceleration, meter
accuracy, thermal stability or native crash recovery. Those require real weights
and actual hardware. No production release until these acceptance gates pass.


## v1.2.5 background recognition

User-submitted images run in an app-scoped queue. Page disposal does not own
or cancel the job. The local engine serializes work; other meters may be queued.
Only the selected image is passed to the configured local/cloud recognition path.
An Android specialUse foreground service with a low-priority notification and
bounded partial wake lock protects work during app switches; it stops when the
queue drains. The Flutter engine is retained across activity recreation.
Completed readings are persisted under application support until the user applies
and saves them; automatic filling checks the captured input baseline so editing
while recognition runs does not overwrite newer input. Force-stop/process death
can interrupt in-flight jobs; this release does not claim to restart such jobs.
Startup model hashing runs in a worker isolate. While hashes are being checked,
the settings panel shows checking, not missing; both final files must still pass
SHA-256 verification. No validation is skipped to manufacture a ready state.
Multi-meter recognition keeps window crops as the preferred path, tries inverted
contrast for dark LCD windows, and falls back to a strict full-image JSON array
when trusted windows cannot be located. Unknown positions stay null; no grid or
synthetic readings are inserted.
