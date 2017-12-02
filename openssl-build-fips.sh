#!/bin/bash

# This script downloads and builds the iOS, tvOS and Mac openSSL libraries with Bitcode enabled and FIPS compliant

# Credits:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# https://gist.github.com/foozmeat/5154962
# Peter Steinberger, PSPDFKit GmbH, @steipete.
# Felix Schwarz, IOSPIRIT GmbH, @felix_schwarz.

set -x

usage ()
{
	echo "usage: $0 [iOS SDK version (defaults to latest)] [tvOS SDK version (defaults to latest)] [OS X minimum deployment target (defaults to 10.7)]"
	exit 127
}

if [ $1 -e "-h" ]; then
	usage
fi

if [ -z $1 ]; then
	IOS_SDK_VERSION="" #"9.1"
	IOS_MIN_SDK_VERSION="8.0"

	TVOS_SDK_VERSION="" #"9.0"
	TVOS_MIN_SDK_VERSION="9.0"

	OSX_DEPLOYMENT_TARGET="10.11"
else
	IOS_SDK_VERSION=$1
	TVOS_SDK_VERSION=$2
	OSX_DEPLOYMENT_TARGET=$3
fi

OPENSSL_VERSION="openssl-1.1.0g"
FIPS_VERSION="openssl-fips-ecp-2.0.16"
INCORE_VERSION="ios-incore-2.0.1"
DEVELOPER=`xcode-select -print-path`

buildIncore()
{
	resetFIPS
	resetIncore
	pushd "${FIPS_VERSION}" > /dev/null

	echo "Building Fips"

	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode "
	SYSTEM="darwin"
	MACHINE="i386"

	SYSTEM="Darwin"
	MACHINE="i386"
	KERNEL_BITS=32

	export MACHINE
	export SYSTEM
	export KERNEL_BITS

	./config &> "/private/tmp/${FIPS_VERSION}-Incore.log"
	make >> "/private/tmp/${FIPS_VERSION}-Incore.log" 2>&1
	echo "Building Incore"
	cd iOS
	make >> "/private/tmp/${FIPS_VERSION}-Incore.log" 2>&1
	echo "Copying incore_macho to /usr/local/bin"
	cp incore_macho /usr/local/bin
	popd > /dev/null
}

buildFIPS()
{
	ARCH=$1
	resetFIPS
	echo "Building ${FIPS_VERSION} for ${ARCH}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
# 		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi

	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode "

	if [[ "${ARCH}" == "x86_64" ]]; then
		TARGET="iphoneos-cross"
	elif [[ "${ARCH}" == "i386" ]]; then
		TARGET="darwin-i386-cc"
	elif [[ "${ARCH}" == "arm64" ]]; then
		TARGET="ios64-cross"
	else
		TARGET="ios-cross"

	fi

	MACHINE=`echo -"$ARCH" | sed -e 's/^-//'`
	SYSTEM="iphoneos"
	BUILD="build"

	export MACHINE
	export SYSTEM
	export BUILD

	#
	# fips/sha/Makefile uses HOSTCC for building fips_standalone_sha1
	#
	export HOSTCC=/usr/bin/cc
	export HOSTCFLAGS="-arch i386"

	pushd . > /dev/null
	cd "${FIPS_VERSION}"
	./Configure no-asm no-shared no-async no-ec2m ${TARGET} --openssldir="/private/tmp/${FIPS_VERSION}-${ARCH}" &> "/private/tmp/${FIPS_VERSION}-${ARCH}.log"
	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
	make >> "/private/tmp/${FIPS_VERSION}-${ARCH}.log" 2>&1
	make install >> "/private/tmp/${FIPS_VERSION}-${ARCH}.log" 2>&1
	make clean >> "/private/tmp/${FIPS_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null
}

buildMac()
{
	ARCH=$1

	echo "Building ${OPENSSL_VERSION} for ${ARCH}"

	TARGET="darwin-i386-cc"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
	fi

	export CC="${BUILD_TOOLS}/usr/bin/clang -fembed-bitcode -mmacosx-version-min=${OSX_DEPLOYMENT_TARGET}"

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
	./Configure no-asm ${TARGET} --openssldir="/private/tmp/${OPENSSL_VERSION}-${ARCH}" &> "/private/tmp/${OPENSSL_VERSION}-${ARCH}.log"
	make >> "/private/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	make install_sw >> "/private/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	make clean >> "/private/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null
}

buildIOS()
{
	ARCH=$1
	resetOpenSSL

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
# 		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi

	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH}"

	#
	# fips/sha/Makefile uses HOSTCC for building fips_standalone_sha1
	#
	export HOSTCC=/usr/bin/cc
	export HOSTCFLAGS="-arch i386"
	export IOS_TARGET=darwin-iphoneos-cross
	export FIPS_SIG=/usr/local/bin/incore_macho
	export CROSS_TYPE=OS
	cross_arch="-armv7"
    cross_type=`echo $CROSS_TYPE | tr '[A-Z]' '[a-z]'`
    MACHINE=`echo "$cross_arch" | sed -e 's/^-//'`
	SYSTEM="iphoneos"
	BUILD="build"

	export MACHINE
	export SYSTEM
	export BUILD

	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

	./Configure fips no-asm no-shared no-async no-ssl2 no-ssl3 no-ec2m iphoneos-cross --prefix="/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --openssldir="/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --with-fipslibdir="/private/tmp/${FIPS_VERSION}-${ARCH}" &> "/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"

	echo "Done Configuring"

	# add -isysroot to CC=
	sed -ie "s!^CFLAGS=!CFLAGS=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
# 	sed -ie "s!^ARFLAGS=!ARFLAGS=-allow_sub_type_mismatches !" "Makefile"
	echo "Running make"
	make >> "/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	echo "Running make install"
	make install >> "/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	echo "Running make clean"
	make clean >> "/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null
}

resetIncore()
{
	rm -rf "${INCORE_VERSION}"
	echo "Unpacking incore"

	tar xfz "${INCORE_VERSION}.tar.gz"
	cp -R "openssl-fips-2.0.1/iOS" ${FIPS_VERSION}
	cp incore_macho.c "${FIPS_VERSION}/iOS"
}

resetFIPS()
{
	rm -rf "${FIPS_VERSION}"
	echo "Unpacking fips"

	tar xfz "${FIPS_VERSION}.tar.gz"
	chmod +x "${FIPS_VERSION}/Configure"
}

resetOpenSSL()
{
	rm -rf "${OPENSSL_VERSION}"
	echo "Unpacking openssl"
	tar xfz "${OPENSSL_VERSION}.tar.gz"
	chmod +x "${OPENSSL_VERSION}/Configure"
}

cleanupTemp()
{
	echo "Cleaning up /tmp"
	rm -rf /private/tmp/${OPENSSL_VERSION}-*
	rm -rf /private/tmp/${FIPS_VERSION}-*
}


echo "Cleaning up"
rm -rf include/openssl/* lib/*

mkdir -p lib
mkdir -p include/openssl/

cleanupTemp


if [ ! -e ${FIPS_VERSION}.tar.gz ]; then
	echo "Downloading ${FIPS_VERSION}.tar.gz"
	curl -O https://www.openssl.org/source/${FIPS_VERSION}.tar.gz
else
	echo "Using ${FIPS_VERSION}.tar.gz"
fi

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	echo "Downloading ${OPENSSL_VERSION}.tar.gz"
	curl -O https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
	echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

if [ ! -e ${INCORE_VERSION}.tar.gz ]; then
	echo "Downloading ${INCORE_VERSION}.tar.gz"
	curl -O http://openssl.com/fips/2.0/platforms/ios/${INCORE_VERSION}.tar.gz
else
	echo "Using ${INCORE_VERSION}.tar.gz"
fi

if [ ! -e incore_macho.c ]; then
	echo "Downloading updated incore_macho.c"
	curl -O https://raw.githubusercontent.com/nilesh1883/incore_macho/master/incore_macho.c
else
	echo "Using incore_macho.c"
fi

echo "Building Incore Library"
buildIncore

echo "Building FIPS iOS libraries"

buildFIPS "armv7s"
buildIOS "armv7s"

buildFIPS "armv7"
buildIOS "armv7"

buildFIPS "arm64"
buildIOS "arm64"

buildFIPS "i386"
buildIOS "i386"
buildMac "i386"

buildFIPS "x86_64"
buildIOS "x86_64"
buildMac "x86_64"


echo "Building iOS libraries"
lipo -create -output lib/libcrypto_iOS.a \
	"/private/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
	"/private/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libcrypto.a" \
	"/private/tmp/${OPENSSL_VERSION}-iOS-armv7s/lib/libcrypto.a"


lipo -create -output lib/libssl_iOS.a \
	"/private/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
	"/private/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libssl.a" \
	"/private/tmp/${OPENSSL_VERSION}-iOS-armv7s/lib/libssl.a"


echo "Adding 64-bit libraries"
lipo \
	"lib/libcrypto_iOS.a" \
	"/private/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
	"/private/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
	-create -output lib/libcrypto_iOS.a

lipo \
	"lib/libssl_iOS.a" \
	"/private/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
	"/private/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
	-create -output lib/libssl_iOS.a


echo "Building OSX libraries"
lipo -create -output lib/libcrypto_mac.a \
	"/private/tmp/${OPENSSL_VERSION}-x86_64/lib/libcrypto.a"\
	"/private/tmp/${OPENSSL_VERSION}-i386/lib/libcrypto.a"


lipo -create -output lib/libssl_mac.a \
	"/private/tmp/${OPENSSL_VERSION}-x86_64/lib/libssl.a" \
	"/private/tmp/${OPENSSL_VERSION}-i386/lib/libssl.a"


echo "Removing old project files"
rm -rf add_to_project

echo "Creating project files"
mkdir -p add_to_project/openssl/bin
mkdir -p add_to_project/openssl/iOS
mkdir -p add_to_project/openssl/mac

cp lib/libssl_iOS.a add_to_project/openssl/iOS/libssl.a
cp lib/libcrypto_iOS.a add_to_project/openssl/iOS/libcrypto.a
cp lib/libssl_mac.a add_to_project/openssl/mac/libssl.a
cp lib/libcrypto_mac.a add_to_project/openssl/mac/libcrypto.a
cp /usr/local/bin/incore_macho add_to_project/openssl/bin/incore_macho
cp -r /private/tmp/${OPENSSL_VERSION}-iOS-armv7/include add_to_project/openssl/include
cp /private/tmp/${FIPS_VERSION}-armv7/lib/fips_premain.c add_to_project/openssl/fips_premain.c

echo "Cleaning up"

cleanupTemp

rm -rf ${OPENSSL_VERSION}
rm -rf ${FIPS_VERSION}

echo "Done..."
echo "Add the openssl directory in ${PWD}/add_to_project to your xcode project"
