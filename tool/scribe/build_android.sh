#!/usr/bin/env bash
# Builds the NeMo-Speech.cpp ASR runtime (CLI + shared libraries) for Android.
# Usage: ANDROID_ABI=arm64-v8a NDK_SYSROOT=... CLANG_RESOURCES=... \
#        tool/scribe/build_android.sh <NeMo-Speech.cpp checkout> <out dir>
# The app's copies live in android/app/src/main/jniLibs/<abi>/ (the .so files
# from <out dir>; the CLI is only for benchmarks).
# Tested with NeMo-Speech.cpp caa3f47 (Oct 2026), clang/lld 18, NDK 28.2 sysroot.
set -euo pipefail
SRC=$(cd "$1" && pwd); OUT=$2
ABI=${ANDROID_ABI:-arm64-v8a}
TC=$(cd "$(dirname "$0")" && pwd)/host-clang-android.cmake
WORK=${WORK:-$SRC/build/android-$ABI}
DEPS=$WORK/deps
if [ "$ABI" = x86_64 ]; then
  ARCH="-DGGML_AVX=ON -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON"
else
  # Snapdragon 845+/Exynos 9820+ class (ARMv8.2 dot product + fp16). Older phones
  # need -DGGML_CPU_ARM_ARCH=armv8-a, or GGML_CPU_ALL_VARIANTS in the app build.
  ARCH="-DGGML_CPU_ARM_ARCH=armv8.2-a+dotprod+fp16"
fi
git -C "$SRC" submodule update --init --depth 1 llama.cpp
# SmartBroker's C API addition (thread count, warm-up); skipped if already applied.
PATCH=$(cd "$(dirname "$0")" && pwd)/patches/0001-c-api-threads-and-warmup.patch
git -C "$SRC" apply --check "$PATCH" 2>/dev/null && git -C "$SRC" apply "$PATCH"
# SentencePiece (static), same commit as scripts/build_sentencepiece_static.sh.
SP=$WORK/sentencepiece
[ -d "$SP/.git" ] || git clone --filter=blob:none --no-checkout https://github.com/google/sentencepiece.git "$SP"
git -C "$SP" fetch --depth 1 origin 31646a467d2051eb904e0b45de3a73e91fe1c1e3
git -C "$SP" checkout --quiet 31646a467d2051eb904e0b45de3a73e91fe1c1e3
cmake -G Ninja -S "$SP" -B "$WORK/sp-build" -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_BUILD_TYPE=Release \
  -DSPM_BUILD_TEST=OFF -DSPM_ENABLE_SHARED=OFF -DSPM_ENABLE_TCMALLOC=OFF
cmake --build "$WORK/sp-build" --target sentencepiece-static
install -D -m 0644 "$WORK/sp-build/src/libsentencepiece.a" "$DEPS/sentencepiece/lib/libsentencepiece.a"
install -D -m 0644 "$SP/src/sentencepiece_processor.h" "$DEPS/sentencepiece/include/sentencepiece_processor.h"
cmake -G Ninja -S "$SRC" -B "$WORK/build" -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_BUILD_TYPE=Release \
  -DNEMO_SPEECH_DEPENDENCY_PREFIX="$DEPS" -DNEMO_SPEECH_GGML_PATCHED=ON -DGGML_LLAMAFILE=ON \
  -DNEMO_SPEECH_BUILD_ASR=ON -DNEMO_SPEECH_BUILD_DIAR=OFF -DNEMO_SPEECH_BUILD_TTS=OFF -DNEMO_SPEECH_BUILD_NMT=OFF \
  -DNEMO_SPEECH_BUILD_MIC_CAPTURE=OFF -DNEMO_SPEECH_BUILD_EXAMPLES=OFF -DNEMO_SPEECH_BUILD_TESTS=OFF \
  -DNEMO_SPEECH_BUILD_TOOLS=OFF -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF $ARCH -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON \
  -DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON  # APKs can only carry lib*.so names
cmake --build "$WORK/build"
mkdir -p "$OUT"
for f in nemo-speech libggml-base.so libggml-cpu.so libggml.so libnemo_speech_asr.so libnemo_speech_asr_c.so; do
  cp -L "$WORK/build/bin/$f" "$OUT/$f"
  llvm-strip --strip-unneeded "$OUT/$f"
done
echo "built $ABI -> $OUT"
