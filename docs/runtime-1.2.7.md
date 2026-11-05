# V1.2.7 local inference runtime

The ARM64 AAR is the official netdur/llama_cpp_dart v0.9.0-dev.12
`llama-cpp-dart-hexagon.aar`, upstream SHA256
`71f252542c7563ba5518c11b68be6cf988a721395c56f2d406cd2acb3f020dec`.
Release: https://github.com/netdur/llama_cpp_dart/releases/tag/v0.9.0-dev.12
Pinned llama.cpp submodule: `afeebe103bd99cda8f5dfaefcabadf890db7fda7`.
The existing MIT license remains in packages/llama_cpp_dart/LICENSE.

Only unneeded ARM64 host debug symbols were stripped with Android NDK
28.2.13676358 llvm-strip. DSP v73/v75/v79/v81 skeletons are unchanged.
All dependent ggml libraries, including OpenCL, remain packaged. The AAR
shrinks from 24.3 MB upstream to approximately 4.9 MB; model files are not bundled.
scripts/prepare_hexagon_runtime.py reproduces this preparation from the pinned
download and rejects an incorrect checksum before replacing the runtime.

ADSP_LIBRARY_PATH must be set before llama_backend_init, which already discovers
backends. Setting it only before a later load_all call caches a failed HTP init.
Discovery and model loading run outside the UI isolate. Auto acceleration selects
the actual HTP device and offloads layers; CPU mode selects no accelerator.
Vision encoding and unsupported operations still execute on CPU. A missing HTP
device or a recoverable initialization failure falls back to CPU.
MediaTek NPU is not enabled by this Qualcomm backend.

Validation is recorded in docs/validation-1.2.7.md. Do not infer successful NPU
execution from the SoC name alone: inspect HTP buffer/layer logs and completed
inference. Public logs and release notes must not contain private sample photos,
tenant data, credentials, or raw account configuration.
