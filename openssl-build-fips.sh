#   Creating output directories
    createOutputDirectories

#   Downloading Source files
    downloadSource

    if [[ "${ENABLE_FIPS}" == "yes" ]]; then
#   Building Incore Library
        buildIncore

#   Building FIPS and OpenSSL for All Arch
        buildFipsForAllArch
    fi

#   Creating combined fat libraries
    createFatLibraries

#   Creating output package
    createOutputPackage
