#!/bin/bash

# This script downloads and builds the iOS, tvOS and Mac openSSL libraries with Bitcode enabled and FIPS compliant

# Credits:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# https://gist.github.com/foozmeat/5154962
# Peter Steinberger, PSPDFKit GmbH, @steipete.
# Felix Schwarz, IOSPIRIT GmbH, @felix_schwarz.
# Nilesh Jaiswal, @nilesh1883.

function main() {

    set -x

    ## set trap to help debug build errors
    #trap 'echo "** ERROR with Build - Check /tmp/openssl*.log"; tail /tmp/openssl*.log' INT TERM EXIT

    if [ $1 -e "-h" ]; then
    	usage
    fi

#   Start clean
    cleanupAll

#   Setting deployment targets
    setDeploymentTargets

#   Setting library versions
    setLibraryVersion

#   Downloading Source files
    downloadSource

#   Building Incore Library
    buildIncore

#   Building FIPS and OpenSSL for All Arch
    buildFipsAllArch

#   Creating combined fat libraries
    createFatLibraries

    echo "Done..."
    echo "Add the openssl directory in ${PWD}/fips_enabled_openssl to your xcode project"

#   Finish clean
    cleanupAll
}

function usage()
{
	echo "usage: $0 [iOS SDK version (defaults to latest)] [tvOS SDK version (defaults to latest)] [OS X minimum deployment target (defaults to 10.7)]"
	exit 127
}

function setDeploymentTargets() {

    if [ -z $1 ]; then
        IOS_SDK_VERSION="" #"11.2"
        IOS_MIN_SDK_VERSION="9.3"

    	TVOS_SDK_VERSION="" #"9.0"
    	TVOS_MIN_SDK_VERSION="9.0"

        OSX_SDK_VERSION="" #"10.13"
    	OSX_DEPLOYMENT_TARGET="10.11"
    else
    	IOS_SDK_VERSION=$1
    	TVOS_SDK_VERSION=$2
    	OSX_DEPLOYMENT_TARGET=$3
    fi
}

function setLibraryVersion() {

    OPENSSL_VERSION="openssl-1.0.2m" #openssl-1.1.0g
    FIPS_VERSION="openssl-fips-ecp-2.0.16"
    INCORE_VERSION="ios-incore-2.0.1"
    DEVELOPER=`xcode-select -print-path`
}

function downloadSource() {

    mkdir -p lib
    mkdir -p include/openssl/

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
}

function createFatLibraries() {

    echo "Create Fat libcrypto iOS libraries"
    lipo -create -output lib/libcrypto_iOS.a \
       "/private/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
       "/private/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libcrypto.a" \
       "/private/tmp/${OPENSSL_VERSION}-iOS-armv7s/lib/libcrypto.a"
    echo "Adding 64-bit libraries"
    lipo \
       "lib/libcrypto_iOS.a" \
       "/private/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
       "/private/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
       -create -output lib/libcrypto_iOS.a

    echo "Create Fat libssl iOS libraries"
    lipo -create -output lib/libssl_iOS.a \
       "/private/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
       "/private/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libssl.a" \
       "/private/tmp/${OPENSSL_VERSION}-iOS-armv7s/lib/libssl.a"
    lipo \
       "lib/libssl_iOS.a" \
       "/private/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
       "/private/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
       -create -output lib/libssl_iOS.a


    echo "Create Fat libcrypto OSX libraries"
    lipo -create -output lib/libcrypto_mac.a \
       "/private/tmp/${OPENSSL_VERSION}-OSX-x86_64/lib/libcrypto.a"\
       "/private/tmp/${OPENSSL_VERSION}-OSX-i386/lib/libcrypto.a"

    echo "Create Fat libssl OSX libraries"
    lipo -create -output lib/libssl_mac.a \
       "/private/tmp/${OPENSSL_VERSION}-OSX-x86_64/lib/libssl.a" \
       "/private/tmp/${OPENSSL_VERSION}-OSX-i386/lib/libssl.a"
}

function createOutputPackage() {

    echo "Removing old project files"
    rm -rf fips_enabled_openssl

    echo "Creating project files"
    mkdir -p fips_enabled_openssl/openssl/bin
    mkdir -p fips_enabled_openssl/openssl/iOS
    mkdir -p fips_enabled_openssl/openssl/mac

    cp lib/libssl_iOS.a fips_enabled_openssl/openssl/iOS/libssl.a
    cp lib/libcrypto_iOS.a fips_enabled_openssl/openssl/iOS/libcrypto.a
    cp lib/libssl_mac.a fips_enabled_openssl/openssl/mac/libssl.a
    cp lib/libcrypto_mac.a fips_enabled_openssl/openssl/mac/libcrypto.a
    cp /usr/local/bin/incore_macho fips_enabled_openssl/openssl/bin/incore_macho
    cp -r /private/tmp/${OPENSSL_VERSION}-iOS-armv7/include fips_enabled_openssl/openssl/include
    cp /private/tmp/${FIPS_VERSION}-armv7/lib/fips_premain.c fips_enabled_openssl/openssl/fips_premain.c
}

function buildFipsAllArch() {

    #echo "Building FIPS iOS libraries"
    #
    #buildFIPS "armv7" "iOS"
    #buildIOS "armv7"
    #
    # buildFIPS "armv7s" "iOS"
    # buildIOS "armv7s"
    #
    #buildFIPS "arm64" "iOS"
    #buildIOS "arm64"
    #
    #buildFIPS "i386" "iOS"
    #buildIOS "i386"
    #
    #buildFIPS "x86_64" "iOS"
    #buildIOS "x86_64"

    echo "Building FIPS OSX libraries"

    #buildFIPS "i386" "OSX"
    #buildMac "i386"

    buildFIPS "x86_64" "OSX"
    buildMac "x86_64"
}

function buildIncore()
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

function buildFIPS()
{
	ARCH=$1
    OS=$2
	resetFIPS
	echo "Building ${FIPS_VERSION} for ${ARCH} and ${OS}"

    if [[ "${OS}" == "iOS" ]]; then
        if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
    		PLATFORM="iPhoneSimulator"
    	else
    		PLATFORM="iPhoneOS"
    # 		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
    	fi
    else
        PLATFORM="MacOSX"
    fi

	export $PLATFORM

    if [[ "${OS}" == "iOS" ]]; then
        export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
        export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode"
    else
        export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -mmacosx-version-min=${OSX_DEPLOYMENT_TARGET}"
    fi

	export BUILD_TOOLS="${DEVELOPER}"

    if [[ "${OS}" == "iOS" ]]; then
        if [[ "${ARCH}" == "x86_64" ]]; then
    		TARGET="iphoneos-cross"
    	elif [[ "${ARCH}" == "i386" ]]; then
    		TARGET="darwin-i386-cc"
    	elif [[ "${ARCH}" == "arm64" ]]; then
    		TARGET="ios64-cross"
    	else
    		TARGET="ios-cross"
    	fi
    else
        if [[ "${ARCH}" == "i386" ]]; then
    		TARGET="darwin-i386-cc"
        elif [[ "${ARCH}" == "x86_64" ]]; then
            TARGET="darwin64-x86_64-cc"
        else
            TARGET="darwin64-x86_64-cc"
        fi
    fi

    if [[ "${OS}" == "iOS" ]]; then
    	SYSTEM="iphoneos"
    else
    	SYSTEM="darwin"
    fi

    MACHINE=`echo -"$ARCH" | sed -e 's/^-//'`
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

    if [[ "${OS}" == "iOS" ]]; then
        sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
    fi

	make >> "/private/tmp/${FIPS_VERSION}-${ARCH}.log" 2>&1
	make install >> "/private/tmp/${FIPS_VERSION}-${ARCH}.log" 2>&1
	make clean >> "/private/tmp/${FIPS_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null
}

function buildMac()
{
    ARCH=$1
    resetOpenSSL

    echo "Building ${OPENSSL_VERSION} for ${ARCH}"

    TARGET="darwin-i386-cc"
    CLANG=`xcrun -f clang`

    if [[ $ARCH == "x86_64" ]]; then
        TARGET="darwin64-x86_64-cc"
    fi

    export BUILD_TOOLS="${DEVELOPER}"
    export CC="${CLANG} -fembed-bitcode -mmacosx-version-min=${OSX_DEPLOYMENT_TARGET}"

    pushd . > /dev/null
    cd "${OPENSSL_VERSION}"
    ./Configure fips no-shared no-async no-ssl3 no-ec2m ${TARGET} --prefix="/private/tmp/${OPENSSL_VERSION}-OSX-${ARCH}" --openssldir="/private/tmp/${OPENSSL_VERSION}-OSX-${ARCH}" --with-fipslibdir="/private/tmp/${FIPS_VERSION}-${ARCH}/lib/"  --with-fipsdir="/private/tmp/${FIPS_VERSION}-${ARCH}" &> "/private/tmp/${OPENSSL_VERSION}-OSX-${ARCH}.log"

    echo "Done Configuring For OSX"

    make >> "/private/tmp/${OPENSSL_VERSION}-OSX-${ARCH}.log" 2>&1
    make install_sw >> "/private/tmp/${OPENSSL_VERSION}-OSX-${ARCH}.log" 2>&1
    make clean >> "/private/tmp/${OPENSSL_VERSION}-OSX-${ARCH}.log" 2>&1
    popd > /dev/null
}

function buildIOS()
{
	ARCH=$1
	resetOpenSSL

pushd . > /dev/null
	cd "${OPENSSL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
        CROSS_TYPE=Simulator
	else
		PLATFORM="iPhoneOS"
        CROSS_TYPE=OS
        sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi

	export $PLATFORM

    # CROSS_TOP is the top of the development tools tree
    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"

    # CROSS_CHAIN is the location of the actual compiler tools
    export CROSS_CHAIN="$CROSS_TOP"/usr/bin/


	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
#    CLANG=`xcrun -f clang`

	#
	# fips/sha/Makefile uses HOSTCC for building fips_standalone_sha1
	#
    echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

	export HOSTCC=/usr/bin/cc
	export HOSTCFLAGS="-arch i386"
	export IOS_TARGET=darwin-iphoneos-cross
	export FIPS_SIG=/usr/local/bin/incore_macho
	cross_arch="-armv7"
    cross_type=`echo $CROSS_TYPE | tr '[A-Z]' '[a-z]'`
    MACHINE=`echo "$cross_arch" | sed -e 's/^-//'`
	SYSTEM="iphoneos"
	BUILD="build"

    # CROSS_COMPILE is the prefix for the tools - in this case the scripts
    # which invoke the tools with the correct options for 'fat' binary handling

#    export CC="${CLANG} -fembed-bitcode -mios-version-min=${IOS_MIN_SDK_VERSION} -arch ${ARCH}"

    echo "****************Nilesh****************"
#    export CC="${CROSS_COMPILE}llvm-gcc -fembed-bitcode -mios-version-min=${IOS_MIN_SDK_VERSION} -arch ${ARCH}"
    echo "****************Nilesh****************"

	export MACHINE
	export SYSTEM
	export BUILD

    export CROSS_COMPILE="`pwd`"/iOS/
    export PATH="`pwd`"/iOS:$PATH

	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

#    ./Configure no-asm no-shared no-async no-ssl2 no-ssl3 no-ec2m iphoneos-cross --prefix="/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --openssldir="/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --with-fipslibdir="/private/tmp/${FIPS_VERSION}-${ARCH}/lib/" --with-fipsdir="/private/tmp/${FIPS_VERSION}-${ARCH}" &> "/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"

    ./Configure fips no-asm no-shared no-async no-ssl2 no-ssl3 no-ec2m iphoneos-cross --prefix="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --with-fipslibdir="/private/tmp/${FIPS_VERSION}-${ARCH}/lib/" --with-fipsdir="/private/tmp/${FIPS_VERSION}-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"

	echo "Done Configuring For iOS"

	# add -isysroot to CC=
    sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"

	echo "Running make"
	make >> "/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	echo "Running make install"
	make install >> "/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	echo "Running make clean"
	make clean >> "/private/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null
}

function resetIncore()
{
    resetEnvironment

    rm -rf "${INCORE_VERSION}"

	echo "Unpacking incore"

	tar xfz "${INCORE_VERSION}.tar.gz"
	cp -R "openssl-fips-2.0.1/iOS" ${FIPS_VERSION}
	cp incore_macho.c "${FIPS_VERSION}/iOS"
}

function resetFIPS()
{
    resetEnvironment

	rm -rf "${FIPS_VERSION}"

	echo "Unpacking fips"

	tar xfz "${FIPS_VERSION}.tar.gz"
	chmod +x "${FIPS_VERSION}/Configure"
}

function resetOpenSSL()
{
	resetEnvironment

    rm -rf "${OPENSSL_VERSION}"

	echo "Unpacking openssl"

	tar xfz "${OPENSSL_VERSION}.tar.gz"
	chmod +x "${OPENSSL_VERSION}/Configure"
}

function cleanupTemp()
{
	echo "Cleaning up /tmp"

	rm -rf /private/tmp/${OPENSSL_VERSION}-*
	rm -rf /private/tmp/${FIPS_VERSION}-*
}

function cleanupAll()
{
    echo "Cleaning up Everything"

    cleanupTemp
    resetEnvironment

    rm -rf include/openssl/* lib/*
    rm -rf ${OPENSSL_VERSION}
    rm -rf ${FIPS_VERSION}
}

function resetEnvironment {

    echo "Reseting Environment Variables"

    unset MACHINE
    unset SYSTEM
    unset CROSS_COMPILE
    unset CROSS_COMPILE_SUFFIX
    unset HOSTCC
    unset FIPS_SIG
    unset INSTALL_PREFIX
    unset cross_arch
}

#   Main Function Call
main
