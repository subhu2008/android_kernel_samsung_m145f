#!/bin/bash

# Initialize git submodules
git submodule update --init --recursive || true

export WDIR="$(dirname $(readlink -f $0))" && cd "$WDIR"
export MERGE_CONFIG="${WDIR}/kernel_platform/common/scripts/kconfig/merge_config.sh"

rm -rf "${WDIR}/dist" \
    && rm -rf "${WDIR}/out" \
    && mkdir -p "${WDIR}/dist"

# Download and install Toolchain
if [ ! -d "${WDIR}/kernel_platform/prebuilts" ]; then
    echo -e "[+] Downloading and installing Toolchain...\n"
    sudo apt install rsync p7zip-full -y
    curl -LO https://github.com/ravindu644/android_kernel_sm_x810/releases/download/toolchain/qcom-5.15-toolchain.tar.gz.zip
    curl -LO https://github.com/ravindu644/android_kernel_sm_x810/releases/download/toolchain/qcom-5.15-toolchain.tar.gz.z01
    7z x qcom-5.15-toolchain.tar.gz.zip && rm qcom-5.15-toolchain.tar.gz.zip qcom-5.15-toolchain.tar.gz.z01
    tar -xf qcom-5.15-toolchain.tar.gz && rm qcom-5.15-toolchain.tar.gz
    mv prebuilts "${WDIR}/kernel_platform" && chmod -R +x "${WDIR}/kernel_platform/prebuilts"    
fi

echo -e "[+] Toolchain installed...\n"


#1. target config
export MODEL="a05s"
export PROJECT_NAME=${MODEL}
export REGION="eur"
export CARRIER="open"
export TARGET_BUILD_VARIANT="user"


#2. sm8550 common config
CHIPSET_NAME="sm6225"

export ANDROID_BUILD_TOP="${WDIR}"
export TARGET_PRODUCT=gki
export TARGET_BOARD_PLATFORM=gki

export ANDROID_PRODUCT_OUT=${ANDROID_BUILD_TOP}/out/target/product/${MODEL}
export OUT_DIR=${ANDROID_BUILD_TOP}/out/msm-${CHIPSET_NAME}-${CHIPSET_NAME}-${TARGET_PRODUCT}

# for Lcd(techpack) driver build
export KBUILD_EXTRA_SYMBOLS="${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/mmrm-driver/Module.symvers"

# for Audio(techpack) driver build
export MODNAME=audio_dlkm

# Run menuconfig only if you want to.
# It's better to use MAKE_MENUCONFIG=0 when everything is already properly enabled, disabled, or configured.
export MAKE_MENUCONFIG=0

HERMETIC_VALUE=1
if [ "$MAKE_MENUCONFIG" = "1" ]; then
    HERMETIC_VALUE=0
fi

# Localversion
export LOCALVERSION="-subhu2008-a05s-kernel"

# custom build options
export GKI_BUILDSCRIPT="./kernel_platform/build/android/prepare_vendor.sh"
export BUILD_OPTIONS=(
    RECOMPILE_KERNEL=1
    SKIP_MRPROPER=0
    TRIM_NONLISTED_KMI=0
    HERMETIC_TOOLCHAIN=$HERMETIC_VALUE
    KMI_SYMBOL_LIST_STRICT_MODE=0
    ABI_DEFINITION=""
    LTO="thin"
)

#3. build kernel
env ${BUILD_OPTIONS[@]} "${GKI_BUILDSCRIPT}" sec ${TARGET_PRODUCT} || exit 1

#4. copy kernel image and boot.img to dist directory
if [ -f "${OUT_DIR}/dist/boot.img" ]; then
    cp "${OUT_DIR}/dist/boot.img" "${WDIR}/dist/boot.img"
else
    echo -e "[-] Error: boot.img not found\n"
    exit 1
fi

if [ -f "${OUT_DIR}/dist/Image" ]; then
    cp "${OUT_DIR}/dist/Image" "${WDIR}/dist/Image"
else
    echo -e "[-] Error: Image not found\n"
    exit 1
fi

echo -e "[+] Kernel build completed successfully\n"
exit 0
