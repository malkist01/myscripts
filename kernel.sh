#!/usr/bin/env bash
# Dependencies
rm -rf kernel
git clone $REPO -b $BRANCH kernel
cd kernel

LOCAL_DIR="$(pwd)/.."
TC_DIR="${LOCAL_DIR}/toolchain"
CLANG_DIR="${TC_DIR}/clang"
ARCH_DIR="${TC_DIR}/aarch64-linux-android-4.9"
ARM_DIR="${TC_DIR}/arm-linux-androideabi-4.9"
setup() {
  if ! [ -d "${CLANG_DIR}" ]; then
      echo "Clang not found! Downloading Google prebuilt..."
      mkdir -p "${CLANG_DIR}"
      wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/4d2864f08ff2c290563fb903a5156e0504620bbe/clang-r563880c.tar.gz -O clang.tar.gz
      if [ $? -ne 0 ]; then
          echo "Download failed! Aborting..."
          exit 1
      fi
        echo "Extracting clang to ${CLANG_DIR}..."
      tar -xf clang.tar.gz -C "${CLANG_DIR}"
    rm -f clang.tar.gz
  fi

  if ! [ -d "${ARCH_DIR}" ]; then
      echo "gcc not found! Cloning to ${ARCH_DIR}..."
      if ! git clone --depth=1 -b main https://github.com/greenforce-project/gcc-arm64 ${ARCH_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if ! [ -d "${ARM_DIR}" ]; then
      echo "gcc_32 not found! Cloning to ${ARM_DIR}..."
      if ! git clone --depth=1 -b main https://github.com/greenforce-project/gcc-arm ${ARM_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi
}
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
DTB=$(pwd)/out/arch/arm64/boot/dtb
DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
KBUILD_COMPILER_STRING=$("$CLANG_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
export PATH="$CLANG_DIR/bin:$ARCH_DIR/bin:$ARM_DIR/bin:$PATH"
CACHE=1
export CACHE
export KBUILD_COMPILER_STRING
ARCH=arm64
export ARCH
export DEFCONFIG="vendor/ginkgo_defconfig"
export ARCH="arm64"
export PATH="$CLANG_DIR/bin:$ARCH_DIR/bin:$ARM_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"
DEVICE="Redmi Note 8"
export DEVICE
CODENAME="ginkgo"
export CODENAME
KVERS="Testing"
export AVERS
COMMIT_HASH=$(git log --oneline --pretty=tformat:"%h  %s  [%an]" --abbrev-commit --abbrev=1 -1)
export COMMIT_HASH
PROCS=$(nproc --all)
export PROCS
STATUS=STABLE
export STATUS
source "${HOME}"/.bashrc && source "${HOME}"/.profile
if [ $CACHE = 1 ]; then
    ccache -M 100G
    export USE_CCACHE=1
fi
LC_ALL=C
export LC_ALL

tg() {
    curl -sX POST https://api.telegram.org/bot"${token}"/sendMessage -d chat_id="${chat_id}" -d parse_mode=Markdown -d disable_web_page_preview=true -d text="$1" &>/dev/null
}

tgs() {
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${token}"/sendDocument \
        -F "chat_id=${chat_id}" \
        -F "parse_mode=Markdown" \
        -F "caption=$2 | *MD5*: \`$MD5\`"
}

# Send Build Info
sendinfo() {
    tg "
• Teletubiescompiler Action •
* Building on*: \`Github actions\`
* Date*: \`${DATE}\`
* Device*: \`${DEVICE} (${CODENAME})\`
* Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
* Compiler*: \`${KBUILD_COMPILER_STRING}\`
* Last Commit*: \`${COMMIT_HASH}\`
* Build Status*: \`${STATUS}\`"
}

# Push kernel to channel
push() {
    cd AnyKernel || exit 1
    ZIP=$(echo *.zip)
    tgs "${ZIP}" "Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). | For *${DEVICE} (${CODENAME})* | ${KBUILD_COMPILER_STRING}"
}

# Catch Error
finderr() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d sticker="CAACAgIAAxkBAAED3JViAplqY4fom_JEexpe31DcwVZ4ogAC1BAAAiHvsEs7bOVKQsl_OiME" \
        -d text="Build throw an error(s)"
    error_sticker
    exit 1
}

# Compile
compile() {

    if [ -d "out" ]; then
        rm -rf out && mkdir -p out
    fi

    make O=out ARCH="${ARCH}" "${DEFCONFIG}"
    make -j"${PROCS}" O=out \
       ARCH="arm64" \
       CC="clang" \
       READELF="llvm-readelf" \
       OBJSIZE="llvm-size" \
       OBJDUMP="llvm-objdump" \
       OBJCOPY="llvm-objcopy" \
       STRIP="llvm-strip" \
       NM="llvm-nm" \
       AR="llvm-ar" \
       HOSTAR="llvm-ar" \
       HOSTAS="llvm-as" \
       HOSTNM="llvm-nm" \
       LD="ld.lld" \
       CLANG_TRIPLE="aarch64-linux-gnu-" \
       CROSS_COMPILE="$ARCH_DIR/bin/aarch64-elf-" \
       CROSS_COMPILE_ARM32="$ARM_DIR/bin/arm-arm-eabi-" \
       Image.gz-dtb \
       dtbo.img \
       CC="${CCACHE} clang" \

    if ! [ -f "${IMAGE}" && -f "${DTBO}" && -f "${DTB}"]; then
        finderr
        exit 1
    fi

    git clone --depth=1 https://github.com/malkist01/AnyKernel2.git AnyKernel -b main
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cp out/arch/arm64/boot/dtbo.img AnyKernel
    cp out/arch/arm64/boot/dtb.img AnyKernel
}
# Zipping
zipping() {
    cd AnyKernel || exit 1
    zip -r9 Teletubies-"${CODENAME}"-"${KVERS}"-"${DATE}".zip ./*
    cd ..
}

setup
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$((END - START))
push
