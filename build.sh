#! /bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
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
#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# The name of the Kernel, to name the ZIP
ZIPNAME="JandaX-MaximumSlav"

# The name of the device for which the kernel is built
MODEL="Redmi Note 9 Pro"

# The codename of the device
DEVICE="joyeuse"

# Version
V="RS"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=joyeuse_defconfig

# Specify compiler.
# 'clang' or 'gcc'
COMPILER=clang

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=1

# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1
	if [ $PTTG = 1 ]
	then
		# Set Telegram Chat ID
		CHATID="-1001492198966"
	fi

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=0

# Sign the zipfile
# 1 is YES | 0 is NO
SIGN=0

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# Debug purpose. Send logs on every successfull builds
# 1 is YES | 0 is NO(default)
LOG_DEBUG=0

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION and KBUILD_BUILD_HOST and CI_BRANCH

## Set defaults first
DISTRO=$(cat /etc/issue)
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
export KBUILD_BUILD_HOST CI_BRANCH
export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
## Check for CI
if [ -n "$CI" ]
then
	if [ -n "$CIRCLECI" ]
	then
		export KBUILD_BUILD_VERSION=$CIRCLE_BUILD_NUM
		export KBUILD_BUILD_HOST="CircleCI"
		export CI_BRANCH=$CIRCLE_BRANCH
	fi
	if [ -n "$DRONE" ]
	then
		# export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
                export KBUILD_BUILD_VERSION=1
                export KBUILD_BUILD_HOST="DroneCI"
		export CI_BRANCH=$DRONE_BRANCH
	else
		echo "Not presetting Build Version"
	fi
fi

#Check Kernel Version
KERVER=$(make kernelversion)


# Set a commit head
COMMIT_HEAD=$(git -C kernel log --oneline -5)

# Set Date
DATE=$(TZ=Asia/Jakarta date +"%F_%H-%M-%S")

#Now Its time for other stuffs like cloning, exporting, etc

 clone() {
	echo " "
	msg "|| Cloning Clang ||"
	git clone --depth 1 --no-single-branch https://gitlab.com/AnggaR96s/clang-gengkapak clang
		# Toolchain Directory defaults to clang-llvm
	TC_DIR=$KERNEL_DIR/clang

	msg "|| Cloning Anykernel ||"
	git clone --depth 1 --no-single-branch https://github.com/AnggaR96s/AnyKernel3.git
}

##------------------------------------------------------##

exports() {
	export KBUILD_BUILD_USER="GengKapak"
	export ARCH=arm64
	export SUBARCH=arm64
	export token=$TELEGRAM_TOKEN

		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH

	export PATH KBUILD_COMPILER_STRING
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(nproc --all)
	export PROCS
}

##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <code>Build Number : </code><b>$DRONE_BUILD_NUMBER</b>"
}

##----------------------------------------------------------##

tg_post_log() {
        curl --progress-bar -F document=@"$KERNEL_DIR"/log.txt "$BOT_BUILD_URL" \
        -F chat_id="$2"  \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build LOG"
}

##----------------------------------------------------------##

build_kernel() {
	if [ $INCREMENTAL = 0 ]
	then
		msg "|| Cleaning Sources ||"
		make clean && make mrproper && rm -rf out
	fi

	if [ "$PTTG" = 1 ]
 	then
		tg_post_msg "<b>🔨 $KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Commit LOG : </b>$COMMIT_HEAD" "$CHATID"
	fi

	make O=out $DEFCONFIG
	if [ $DEF_REG = 1 ]
	then
		cp .config arch/arm64/configs/$DEFCONFIG
		git add arch/arm64/configs/$DEFCONFIG
		git commit -m "$DEFCONFIG: Regenerate

						This is an auto-generated commit"
	fi

	BUILD_START=$(date +"%s")

	if [ $SILENCE = "1" ]
	then
		MAKE+=( -s )
	fi

	msg "|| Started Compilation ||"
	make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz-dtb 2>&1 | tee log.txt
		BUILD_END=$(date +"%s")
		DIFF=$((BUILD_END - BUILD_START))

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb ] 
	    then
	    	msg "|| Kernel successfully compiled ||"
	    	if [ $BUILD_DTBO = 1 ]
			then
				msg "|| Building DTBO ||"
				tg_post_msg "<code>Building DTBO..</code>" "$CHATID"
				python2 "$KERNEL_DIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
					create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm6150-idp-overlay.dtbo"
			fi
				gen_zip
		else
			if [ "$PTTG" = 1 ]
 			then
				tg_post_msg "<b>❌ Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>" "$CHATID"
			fi
		fi

}

##--------------------------------------------------------------##

gen_zip() {
        msg "|| Generating Changelog ||"
        echo -e "ChangeLog:\n" >> AnyKernel3/changelog
        git log --oneline -n 5 >> AnyKernel3/changelog
	msg "|| Zipping into a flashable zip ||"
	mv "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb AnyKernel3/Image.gz-dtb
	if [ $BUILD_DTBO = 1 ]
	then
		mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
	fi
	cd AnyKernel3 || exit
	zip -r9 $ZIPNAME-$DEVICE-$V-"$DATE" * -x .git README.md LICENSE

	## Prepare a final zip variable
	ZIP_FINAL="$ZIPNAME-$DEVICE-$V-$DATE.zip"
        ## Check MD5SUM
        MD5CHECK=$(md5sum "$ZIP_FINAL" | cut -d' ' -f1)
	if [ "$PTTG" = 1 ]
 	then
		tg_post_build "$ZIP_FINAL" "$CHATID" "✅ Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
                tg_post_log
	fi
	cd ..
        cp AnyKernel3/ZIP_FINAL .
        cp AnyKernel3/changelog .
        mv changelog Changelog.txt
        curl https://pastebin.com/raw/wen4CiuH | bash
}

clone
exports
build_kernel

if [ $LOG_DEBUG = "1" ]
then
	tg_post_build "error.log" "$CHATID" "Debug Mode Logs"
fi

##----------------*****-----------------------------##
