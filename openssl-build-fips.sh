#   Creating output directories
    createOutputDirectories

#   Downloading Source files
    downloadSource

#   Building Incore Library
    buildIncore

#   Building FIPS and OpenSSL for All Arch
    buildFipsForAllArch

#   Creating combined fat libraries
    createFatLibraries
		./Configure fips ${TARGET} ${OPENSSL_OPTION} --prefix="${TEMP}/${OPENSSL_VERSION}-OSX-${ARCH}" --openssldir="${TEMP}/${OPENSSL_VERSION}-OSX-${ARCH}" --with-fipslibdir="${TEMP}/${FIPS_VERSION}-${ARCH}/lib/"  --with-fipsdir="${TEMP}/${FIPS_VERSION}-${ARCH}" &> "${TEMP}/${OPENSSL_VERSION}-OSX-${ARCH}.log"
    else
		./Configure ${TARGET} ${OPENSSL_OPTION} --prefix="${TEMP}/${OPENSSL_VERSION}-OSX-${ARCH}" --openssldir="${TEMP}/${OPENSSL_VERSION}-OSX-${ARCH}" &> "${TEMP}/${OPENSSL_VERSION}-OSX-${ARCH}.log"
    fi

    if [[ "${ENABLE_BITCODE}" == "yes" ]]; then
        sed -ie 's!^CFLAG=!CFLAG=-fembed-bitcode !' 'Makefile'
    fi
    # sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mmacosx-version-min=${OSX_DEPLOYMENT_TARGET} !" "Makefile"

    echo "Done Configuring For OSX"

    make clean
    else
        PLATFORM="iPhoneOS"
        # CROSS_TYPE=OS
        # sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
    fi

    TARGET="iphoneos-cross"

    export ARCH=${ARCH}
    export PLATFORM=${PLATFORM}
    export HOSTCC=/usr/bin/cc
    export HOSTCFLAGS="-arch x86_64"
    else
	    ./Configure ${TARGET} ${OPENSSL_OPTION}  --prefix="${TEMP}/${OPENSSL_VERSION}-iOS-${ARCH}" --openssldir="${TEMP}/${OPENSSL_VERSION}-iOS-${ARCH}" &> "${TEMP}/${OPENSSL_VERSION}-iOS-${ARCH}.log"
    fi

   	# add -isysroot to CC=
    if [[ "${ENABLE_BITCODE}" == "yes" ]]; then
        sed -ie 's!^CFLAG=!CFLAG=-fembed-bitcode !' 'Makefile'
    fi

    if [[ "${ARCH}" == "armv7" ]]; then
        sed -ie 's!^CFLAG=!CFLAG=-arch armv7 !' 'Makefile'
    elif [[ "${ARCH}" == "arm64" ]]; then
        sed -ie 's!^CFLAG=!CFLAG=-arch arm64 !' 'Makefile'
    rm -rf "${OPENSSL_VERSION}"

	echo "Unpacking openssl"
	tar xfz "${OPENSSL_VERSION}.tar.gz"
	chmod +x "${OPENSSL_VERSION}/Configure"
	
    #modify secure coding
    cp -f ${OPENSSL_VERSION}/crypto/mem.c ${OPENSSL_VERSION}/crypto/mem_old.c
    cat ${OPENSSL_VERSION}/crypto/mem.c | sed 's/strcpy(ret, str);/memset(ret, 0, strlen(str) + 1);\
    \#ifdef _WIN32\
    strcpy_s(ret, str, strlen(str));\
    \#else	\
    strncpy(ret, str, strlen(str));\
    \#endif/g' > mem_new.c	
    cp -f mem_new.c ${OPENSSL_VERSION}/crypto/mem.c	
}

function cleanupTemp() {
	echo "Cleaning up /tmp"

	rm -rf ${TEMP}/${OPENSSL_VERSION}-*
