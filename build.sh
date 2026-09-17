#!/usr/bin/env bash
# DGKI Local Build Script

set -o pipefail

# Directories
KERNEL_DIR="$PWD"
BASE_DIR="$PWD/../../../"
OUT_DIR="$KERNEL_DIR/out"
LOG_FILE="$OUT_DIR/kernel_compile.log"

# Ccache Config
export CCACHE_EXEC=/usr/bin/ccache
export USE_CCACHE=1
export CCACHE_DIR="$BASE_DIR/ccache/.kernel"

# Clang Path & Environment
CLANG="$BASE_DIR/prebuilts/clang/host/linux-x86/clang-r563880c/bin"
AK3_DIR="$KERNEL_DIR/../AnyKernel3"

export ARCH=arm64
export SUBARCH=ARM64
export KBUILD_BUILD_TIMESTAMP="$(TZ=Asia/Ho_Chi_Minh date)"
export PATH="$CLANG:$PATH"

# Configs
CODENAME="munch"
DEFCONFIG="munch_defconfig"

# Make Flags
MAKE_FLAGS=(
    O=out
    ARCH=arm64
    SUBARCH=ARM64
    CC="ccache clang"
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
    LLVM=1
    LLVM_IAS=1
)

echo "=== Starting build for $CODENAME ==="

[[ ! -d "$AK3_DIR" ]] && echo "Error: AnyKernel3 not found at $AK3_DIR" && exit 1

mkdir -p "$OUT_DIR"
rm -f "$LOG_FILE"

make "${MAKE_FLAGS[@]}" "$DEFCONFIG" 2>&1 | tee -a "$LOG_FILE"
yes "" | make "${MAKE_FLAGS[@]}" olddefconfig 2>&1 | tee -a "$LOG_FILE"

make "${MAKE_FLAGS[@]}" -j$(nproc --all) 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Error: Build failed!"
    exit 1
fi

make "${MAKE_FLAGS[@]}" dtbo.img 2>&1 | tee -a "$LOG_FILE" || true

rm -f "$AK3_DIR/Image" "$AK3_DIR/dtbo.img" "$AK3_DIR/dtb" "$AK3_DIR/dtb.img"

[[ -f "$OUT_DIR/arch/arm64/boot/Image" ]] && cp "$OUT_DIR/arch/arm64/boot/Image" "$AK3_DIR/"
[[ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]] && cp "$OUT_DIR/arch/arm64/boot/dtbo.img" "$AK3_DIR/"
[[ -f "$OUT_DIR/arch/arm64/boot/dtb" ]] && cp "$OUT_DIR/arch/arm64/boot/dtb" "$AK3_DIR/dtb.img"
[[ -f "$OUT_DIR/arch/arm64/boot/dtb.img" ]] && cp "$OUT_DIR/arch/arm64/boot/dtb.img" "$AK3_DIR/"

cd "$AK3_DIR"
ZIP_NAME="DGKI-${CODENAME}-$(date +%Y%m%d-%H%M).zip"
zip -r9 "$OUT_DIR/$ZIP_NAME" * -x ".git*" ".github*" README.md 2>&1
cd "$KERNEL_DIR"

echo "=== Build Success: $OUT_DIR/$ZIP_NAME ==="