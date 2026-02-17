#!/bin/bash
# shellcheck disable=SC2154

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2021 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

# Kernel building script
WORKDIR="$(pwd)"
KERNEL="$WORKDIR/kernel"
TC_DIR="${LOCAL_DIR}/toolchain"
CLANG_DIR="${TC_DIR}/clang"
ARCH_DIR="${TC_DIR}/aarch64-linux-android-4.9"
ARM_DIR="${TC_DIR}/arm-linux-androideabi-4.9"

# Cloning Sources
git clone --single-branch --depth=1 https://github.com/neophyteprjkt/kernel_xiaomi_ginkgo -b 13 $KERNEL && cd $KERNEL
export LOCALVERSION=+malkist
export PATH="$CLANG_DIR/bin:$ARCH_DIR/bin:$ARM_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"

# Bail out if script fails
set -e

# Function to show an informational message
msger()
{
	while getopts ":n:e:" opt
	do
		case "${opt}" in
			n) printf "[*] $2 \n" ;;
			e) printf "[×] $2 \n"; return 1 ;;
		esac
	done
}

cdir()
{
	cd "$1" 2>/dev/null || msger -e "The directory $1 doesn't exists !"
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR="$(pwd)"
BASEDIR="$(basename "$KERNEL_DIR")"

# PATCH KERNELSU & RELEASE VERSION
KSU=0
RELEASE=R1

# The name of the Kernel, to name the ZIP
ZIPNAME="Teletubies"
if [ $KSU = 1 ]
then
   VER="$RELEASE-KSU"
else
    VER="$RELEASE-NONKSU"
fi

# Build Author
# Take care, it should be a universal and most probably, case-sensitive
AUTHOR="malkist01"
HOSTR="android"

# Architecture
ARCH=arm64

# The name of the device for which the kernel is built
MODEL="Redmi Note 8"

# The codename of the device
DEVICE="ginkgo"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=vendor/ginkgo_defconfig

# Specify compiler.
# 'clang' or 'gcc'
COMPILER=clang		


# Toolchain Directory defaults to clang-llvm
CLANG_VERSION="clang-20.0.0"

# Build modules. 0 = NO | 1 = YES
MODULES=0

# Specify linker.
# 'ld.lld'(default)
LINKER=ld.lld

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=0

# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1
if [ $PTTG = 1 ]
then
	# Set Telegram Chat ID
	CHATID="-1002287610863"
	TOKEN="7868194496:AAGY7WwRRbeCOPYOnczoCPh2psC43Q0F3JI"
fi

# Files/artifacts
FILES=Image.gz

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=0
if [ $BUILD_DTBO = 1 ]
then
	# Set this to your dtbo path.
	# Defaults in folder out/arch/arm64/boot/dts
	DTBO_PATH="xiaomi/ginkgo-trinket-overlay.dtbo"
fi

# Sign the zipfile
# 1 is YES | 0 is NO
SIGN=0
if [ $SIGN = 1 ]
then
	#Check for java
	if ! hash java 2>/dev/null 2>&1; then
		SIGN=0
		msger -n "you may need to install java, if you wanna have Signing enabled"
	else
		SIGN=1
	fi
fi

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# Verbose build
# 0 is Quiet(default)) | 1 is verbose | 2 gives reason for rebuilding targets
VERBOSE=0

# Debug purpose. Send logs on every successfull builds
# 1 is YES | 0 is NO(default)
LOG_DEBUG=0

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION and KBUILD_BUILD_HOST and CI_BRANCH

## Set defaults first

# shellcheck source=/etc/os-release
export DISTRO=$(source /etc/os-release && echo "${NAME}")
export KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
TERM=xterm

#Check Kernel Version
KERVER=$(make kernelversion)

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")
WAKTU=$(date +"%F-%S")

#Now Its time for other stuffs like cloning, exporting, etc

 clone()
 {
	echo " "
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

	msger -n "|| Cloning Anykernel ||"
	git clone --depth=1 https://github.com/malkist01/AnyKernel2 -b master AnyKernel3

	if [ $BUILD_DTBO = 1 ]
	then
		msger -n "|| Cloning libufdt ||"
		git clone https://android.googlesource.com/platform/system/libufdt "$KERNEL_DIR"/scripts/ufdt/libufdt
	fi
}

##------------------------------------------------------##

exports()
{
	KBUILD_BUILD_USER=$AUTHOR
	KBUILD_BUILD_HOST=$HOSTR
	SUBARCH=$ARCH

	if [ $COMPILER = "clang" ]
	then
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH
	elif [ $COMPILER = "gcc" ]
	then
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi

	BOT_MSG_URL="https://api.telegram.org/bot$TOKEN/sendMessage"
	BOT_BUILD_URL="https://api.telegram.org/bot$TOKEN/sendDocument"
	PROCS=$(nproc --all)

	export KBUILD_BUILD_USER ARCH SUBARCH PATH \
	       KBUILD_COMPILER_STRING BOT_MSG_URL \
	       BOT_BUILD_URL PROCS
}

##---------------------------------------------------------##

tg_post_msg()
{
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------##

tg_post_build()
{
	# Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	# Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$CHATID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5CHECK\`"
}

##----------------------------------------------------------##

build_kernel()
{
	if [ $INCREMENTAL = 0 ]
	then
		msger -n "|| Cleaning Sources ||"
		make mrproper && rm -rf out
	fi

	if [ "$KSU" = 1 ]
 	then
		tg_post_msg "<b>Teletubies CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>KernelSU: </b><code>Yes This KSU</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>"
	else
		tg_post_msg "<b>Teletubies CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>NON KernelSU:<code>No KSU</code>%0A</b><b>Top Commit : </b><code>$COMMIT_HEAD</code>"
    	fi
	
	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")
	if [ $COMPILER = "clang" ]
	then
		MAKE+=(
        ARCH=arm64 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        Image.gz-dtb \
        dtbo.img 2>&1 | tee log.txt
     ) 
	elif [ $COMPILER = "gcc" ]
	then
		MAKE+=(
			CROSS_COMPILE_ARM32=arm-eabi- \
			CROSS_COMPILE=aarch64-elf- \
			AR=aarch64-elf-ar \
			OBJDUMP=aarch64-elf-objdump \
			STRIP=aarch64-elf-strip \
			NM=aarch64-elf-nm \
			OBJCOPY=aarch64-elf-objcopy \
			LD=aarch64-elf-$LINKER
		)
	fi

	if [ $SILENCE = "1" ]
	then
		MAKE+=( -s )
	fi

	msger -n "|| Started Compilation ||"
	make -kj"$PROCS" O=out \
		V=$VERBOSE \
		"${MAKE[@]}" 2>&1 | tee error.log
	if [ $MODULES = "1" ]
	then
	    msger -n "|| Started Compiling Modules ||"
	    make -j"$PROCS" O=out INSTALL_MOD_PATH="$KERNEL_DIR"/out/modules INSTALL_MOD_STRIP=1 modules_install
	    find "$KERNEL_DIR"/out/modules -type f -iname '*.ko' -exec cp {} AnyKernel3/modules/system/lib/modules/ \;
	fi

		BUILD_END=$(date +"%s")
		DIFF=$((BUILD_END - BUILD_START))

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/$FILES ]
		then
			msger -n "|| Kernel successfully compiled ||"
			if [ $BUILD_DTBO = 1 ]
			then
				msger -n "|| Building DTBO ||"
				tg_post_msg "<code>Building DTBO..</code>"
				python2 "$KERNEL_DIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
					create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/$DTBO_PATH"
			fi
				gen_zip
			else
			if [ "$PTTG" = 1 ]
 			then
				tg_post_build "error.log" "*Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds*"
			fi
		fi

}

##--------------------------------------------------------------##

gen_zip()
{
	msger -n "|| Zipping into a flashable zip ||"
	cp "$KERNEL_DIR"/out/arch/arm64/boot/$FILES AnyKernel3/$FILES
	cp "$KERNEL_DIR"/out/.config AnyKernel3/config
	cp "$KERNEL_DIR"/out/arch/arm64/boot/dtb.img AnyKernel3/dtb
	cp "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
#	cp "$KERNEL_DIR"/out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} AnyKernel3/modules/system/lib/modules/
#	cp "$KERNEL_DIR"/out/modules/lib/modules/5.4*/modules.order AnyKernel3/modules/system/lib/modules/modules.load
	if [ $BUILD_DTBO = 1 ]
	then
		mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
	fi
	cdir AnyKernel3
	zip -r $ZIPNAME-$DEVICE-$VER-"$WAKTU" . -x ".git*" -x "README.md" -x "*.zip"

	## Prepare a final zip variable
	ZIP_FINAL="$ZIPNAME-$DEVICE-$VER-$WAKTU"

	if [ $SIGN = 1 ]
	then
		## Sign the zip before sending it to telegram
		if [ "$PTTG" = 1 ]
 		then
 			msger -n "|| Signing Zip ||"
			tg_post_msg "<code>Signing Zip file with AOSP keys..</code>"
 		fi
		curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
		java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
		ZIP_FINAL="$ZIP_FINAL-signed"
	fi

	if [ "$PTTG" = 1 ]
 	then
		tg_post_build "$ZIP_FINAL.zip" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	fi
	cd ..
}

clone
exports
build_kernel

if [ $LOG_DEBUG = "1" ]
then
	tg_post_build "error.log" "$CHATID" "Debug Mode Logs"
fi

##----------------*****-----------------------------##