"""Recreate the checked-in ARM64 runtime from the pinned upstream AAR.

python scripts/prepare_hexagon_runtime.py --strip /path/to/llvm-strip [--input file.aar]
Downloads only the public upstream artifact; never reads app credentials.
"""
import argparse
import hashlib
import io
from pathlib import Path
import subprocess
import urllib.request
import zipfile

URL = 'https://github.com/netdur/llama_cpp_dart/releases/download/v0.9.0-dev.12/llama-cpp-dart-hexagon.aar'
SHA256 = '71f252542c7563ba5518c11b68be6cf988a721395c56f2d406cd2acb3f020dec'
ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--strip', required=True, type=Path)
    args = parser.parse_args()
    data = args.input.read_bytes() if args.input else urllib.request.urlopen(URL, timeout=120).read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit('Upstream checksum mismatch; runtime unchanged')
    scratch = (ROOT / 'build' / 'hexagon-runtime').resolve()
    assert scratch.is_relative_to((ROOT / 'build').resolve())
    scratch.mkdir(parents=True, exist_ok=True)
    output = io.BytesIO()
    with zipfile.ZipFile(io.BytesIO(data)) as source, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as dest:
        for entry in sorted(source.namelist()):
            if entry.endswith('/'):
                continue
            content = source.read(entry)
            # DSP skeletons use the Hexagon ELF architecture; ARM llvm-strip
            # must never rewrite them. Keep every required host dependency.
            if entry.startswith('jni/arm64-v8a/') and entry.endswith('.so') and '/libggml-htp-' not in entry:
                temp = scratch / Path(entry).name
                temp.write_bytes(content)
                subprocess.run([str(args.strip), '--strip-unneeded', str(temp)], check=True)
                content = temp.read_bytes()
            info = zipfile.ZipInfo(entry, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            dest.writestr(info, content)
    target = ROOT / 'packages/llama_cpp_dart/native/android/llama-cpp-dart.aar'
    target.write_bytes(output.getvalue())
    print(f'Prepared {target.name}: {target.stat().st_size:,} bytes')


if __name__ == '__main__':
    main()
