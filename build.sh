#!/usr/bin/env bash
#
# Copyright (C) 2023 Kneba <abenkenary3@gmail.com>
#

# Function to show an informational message
msg() {
	echo
    echo -e "\e[1;32m$*\e[0m"
    echo
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

cdir() {
	cd "$1" 2>/dev/null || \
		err "The directory $1 doesn't exists !"
}

# Main
MainPath="$(pwd)"
MainClangPath="${MainPath}/clang"
MainClangZipPath="${MainPath}/clang-zip"
ClangPath="${MainClangZipPath}"

# Identity
VERSION=9x13
KERNELNAME=TheOneMemory
CODENAME=Onyx
VARIANT=EAS

# Show manufacturer info
MANUFACTURERINFO="ASUSTek Computer Inc."

# Clone Kernel Source
git clone --depth=1 https://$USERNAME:$TOKEN@github.com/$USERNAME/Ruega-Kernel-X00T -b easu kernel

# Clone AOSP Clang
ClangPath=${MainClangZipPath}
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
mkdir $ClangPath
rm -rf $ClangPath/*

git clone --depth=1 https://gitlab.com/strongreasons/stress-clang.git $ClangPath
#git clone --depth=1 https://gitlab.com/ImSurajxD/clang-r450784d -b master $ClangPath
#wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/b52bad393812a7051b3a1294efa80ad2d9380ad1/clang-r458507.tar.gz -O "clang-r458507.tar.gz"
#tar -xf clang-r458507.tar.gz -C $ClangPath

# Prepare
KERNEL_ROOTDIR=$(pwd)/kernel # IMPORTANT ! Fill with your kernel source root directory.
export LD=ld.lld
export KBUILD_BUILD_USER=queen # Change with your own name or else.
export KBUILD_BUILD_HOST=Energy Aware Scheduling # Change with your own host or else.
IMAGE=$(pwd)/kernel/out/arch/arm64/boot/Image.gz-dtb
CLANG_VER="$("$ClangPath"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
LLD_VER="$("$ClangPath"/bin/ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING="$CLANG_VER with $LLD_VER"
DATE=$(date +"%Y-%m-%d")
START=$(date +"%s")

# Java
command -v java > /dev/null 2>&1

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

# Telegram messaging
tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="$1"
}
# Compiler
compile(){
cd ${KERNEL_ROOTDIR}
export HASH_HEAD=$(git rev-parse --short HEAD)
export COMMIT_HEAD=$(git log --oneline -1)
make -j$(nproc) O=out ARCH=arm64 X00TD_defconfig
make -j$(nproc) ARCH=arm64 SUBARCH=ARM64 O=out \
    LD_LIBRARY_PATH="${ClangPath}/lib64:${LD_LIBRARY_PATH}" \
    PATH=$ClangPath/bin:${PATH} \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    CC=clang \
    AR=llvm-ar \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    LD="ld.lld"

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi
   git clone https://github.com/strongreasons/AnyKernel3 -b eas AnyKernel
	cp $IMAGE AnyKernel
}
# Push kernel to telegram
function push() {
    cd AnyKernel
    curl -F document="@$ZIP_FINAL.zip" "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="🔐<b>Build Done</b>
        - <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s)... </code>

        <b>📅 Build Date: </b>
        -<code>$DATE</code>

        <b>🐧 Linux Version: </b>
        -<code>4.4.302</code>

         <b>💿 Compiler: </b>
        -<code>$KBUILD_COMPILER_STRING</code>

        <b>📱 Device: </b>
        -<code>X00TD($MANUFACTURERINFO)</code>

        <b>🆑 Changelog: </b>
        - <code>$COMMIT_HEAD</code>
        <b></b>
        #$KERNELNAME #$CODENAME #$VARIANT"
}
# Find Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="❌ Tetap menyerah...Pasti bisa!!!"
    exit 1
}
# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 [$VERSION]$KERNELNAME-$CODENAME-$VARIANT-"$DATE" . -x ".git*" -x "README.md" -x "*.zip"

    ZIP_FINAL="[$VERSION]$KERNELNAME-$CODENAME-$VARIANT-$DATE"

    msg "|| Signing Zip ||"
    tg_post_msg "<code>🔑 Signing Zip file with AOSP keys..</code>"

    curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
    java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
    ZIP_FINAL="$ZIP_FINAL-signed"
    cd ..
}
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
