#!/bin/bash
# © Copyright IBM Corporation 2019, 2020
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
#
# Instructions:
# Download build script: wget https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Boringssl/build_boringssl.sh
# Execute build script: bash build_boringssl.sh   (provide -h for help)

set -e -o pipefail

PACKAGE_NAME="boringssl"
CURDIR="$(pwd)"
GIT_BRANCH="patch-s390x-Aug2019"

TESTS="false"
FORCE="false"
LOG_FILE="$CURDIR/logs/${PACKAGE_NAME}-${GIT_BRANCH}-$(date +"%F-%T").log"

trap cleanup 0 1 2 ERR

#Check if directory exists
if [ ! -d "$CURDIR/logs/" ]; then
    mkdir -p "$CURDIR/logs/"
fi

# Need handling for RHEL 6.10 as it doesn't have os-release file
if [ -f "/etc/os-release" ]; then
    source "/etc/os-release"
else
    cat /etc/redhat-release >>"${LOG_FILE}"
    export ID="rhel"
    export VERSION_ID="6.x"
    export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
fi

function prepare() {
    if command -v "sudo" >/dev/null; then
        printf -- 'Sudo : Yes\n' >>"$LOG_FILE"
    else
        printf -- 'Sudo : No \n' >>"$LOG_FILE"
        printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
        exit 1
    fi

    if [[ "$FORCE" == "true" ]]; then
        printf -- 'Force attribute provided hence continuing with install without confirmation message\n' |& tee -a "$LOG_FILE"
    else
        # Ask user for prerequisite installation
        printf -- "\nAs part of the installation , dependencies would be installed/upgraded.\n"
        while true; do
            read -r -p "Do you want to continue (y/n) ? :  " yn
            case $yn in
            [Yy]*)
                printf -- 'User responded with Yes. \n' >>"$LOG_FILE"
                break
                ;;
            [Nn]*) exit ;;
            *) echo "Please provide confirmation to proceed." ;;
            esac
        done
    fi
}

function cleanup() {
    # Remove artifacts

    if [ -f "$CURDIR/otp_src_${PACKAGE_VERSION}.tar.gz" ]; then
        rm -rf "$CURDIR/otp_src_${PACKAGE_VERSION}.tar.gz"
    fi
    printf -- "Cleaned up the artifacts\n" >>"$LOG_FILE"
}

function buildGCC() {

	printf -- 'Building GCC \n' |& tee -a "$LOG_FILE"
	cd "${CURDIR}"
	wget https://ftpmirror.gnu.org/gcc/gcc-7.4.0/gcc-7.4.0.tar.xz
	tar -xf gcc-7.4.0.tar.xz
	cd gcc-7.4.0/
	./contrib/download_prerequisites
	mkdir gcc_build
	cd gcc_build/
	../configure --prefix=/opt/gcc --enable-languages=c,c++ --with-arch=zEC12 --with-long-double-128 \
		--build=s390x-linux-gnu --host=s390x-linux-gnu --target=s390x-linux-gnu \
		--enable-threads=posix --with-system-zlib --disable-multilib
	make -j 8
	sudo make install
	sudo ln -sf /opt/gcc/bin/gcc /usr/bin/gcc
	sudo ln -sf /opt/gcc/bin/g++ /usr/bin/g++
	sudo ln -sf /opt/gcc/bin/g++ /usr/bin/c++
	export PATH=/opt/gcc/bin:"$PATH"
	export LD_LIBRARY_PATH=/opt/gcc/lib64:"$LD_LIBRARY_PATH"
	export C_INCLUDE_PATH=/opt/gcc/lib/gcc/s390x-linux-gnu/7.4.0/include
	export CPLUS_INCLUDE_PATH=/opt/gcc/lib/gcc/s390x-linux-gnu/7.4.0/include

	#for rhel
	if [[ "${ID}" == "rhel" ]]; then
		sudo ln -sf /opt/gcc/lib64/libstdc++.so.6.0.24 /lib64/libstdc++.so.6
	else
		sudo ln -sf /opt/gcc/lib64/libstdc++.so.6.0.24 /usr/lib/s390x-linux-gnu/libstdc++.so.6
	fi
	printf -- 'Built GCC successfully \n' |& tee -a "$LOG_FILE"

}


function configureAndInstall() {
    printf -- "Configuration and Installation started \n"

	if [ "${VERSION_ID}" == "7.5" ] || [ "${VERSION_ID}" == "7.6" ] || [ "${VERSION_ID}" == "7.7" ]; then
		cd "${CURDIR}"
		wget https://cmake.org/files/v3.7/cmake-3.7.2.tar.gz
		tar xzf cmake-3.7.2.tar.gz
		cd cmake-3.7.2
		./configure --prefix=/usr/local
		make && sudo make install
	fi
	# Download and Install Go v1.12.5
	cd $CURDIR
    wget https://storage.googleapis.com/golang/go1.12.5.linux-s390x.tar.gz
    tar -xzf go1.12.5.linux-s390x.tar.gz
    export PATH=$CURDIR/go/bin:$PATH
    export GOROOT=$CURDIR/go
	export GOPATH=$CURDIR/go/bin
    go version
	
    # Download Boringssl
    cd $CURDIR
    git clone https://github.com/linux-on-ibm-z/boringssl
    cd boringssl
    git checkout patch-s390x-Aug2019

    # Build Boringssl
    cd $CURDIR/boringssl
	mkdir build
	cd build/
	cmake ..
	make
    printf -- "Build for Boringssl is successful\n" 

    # Run Test
    runTest

    # Cleanup
    cleanup

    # # Verify erlang installation
    # if command -v "erl" >/dev/null; then
        # printf -- " %s Installation verified.\n" "$PACKAGE_NAME"
    # else
        # printf -- "Error while installing %s, exiting with 127 \n" "$PACKAGE_NAME"
        # exit 127
    # fi
}

function runTest() {

    set +e
    if [[ "$TESTS" == "true" ]]; then
        printf -- 'Running tests \n\n' |& tee -a "$LOG_FILE"
        cd $CURDIR/boringssl/build
		./crypto/crypto_test |& tee $CURDIR/crypto_tests.log
		cd $CURDIR/boringssl/build
		./ssl/ssl_test |& tee $CURDIR/ssl_tests.log
		cd $CURDIR/boringssl
		go run util/all_tests.go |& tee $CURDIR/all_tests.log
		cd $CURDIR/boringssl/ssl/test/runner
		go test |& tee $CURDIR/blackbox_tests.log
    fi

    set -e
}

function logDetails() {
    printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"
    if [ -f "/etc/os-release" ]; then
        cat "/etc/os-release" >>"$LOG_FILE"
    fi

    cat /proc/version >>"$LOG_FILE"
    printf -- '*********************************************************************************************************\n' >>"$LOG_FILE"
    printf -- "Detected %s \n" "$PRETTY_NAME"
    printf -- "Request details : PACKAGE NAME= %s , GIT_BRANCH= %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" |& tee -a "$LOG_FILE"
}

# Print the usage message
function printHelp() {
    echo
    echo "Usage: "
    echo " build_boringssl.sh  [-d debug] [-y install-without-confirmation] [-t install and run tests]"
    echo
}

while getopts "h?dyt" opt; do
    case "$opt" in
    h | \?)
        printHelp
        exit 0
        ;;
    d)
        set -x
        ;;
    y)
        FORCE="true"
        ;;
    t)
        TESTS="true"
        ;;
    esac
done

logDetails
prepare # Check Prerequisites
DISTRO="$ID-$VERSION_ID"

case "$DISTRO" in
"ubuntu-16.04")
    printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" "$DISTRO" |& tee -a "$LOG_FILE"
    printf -- "Installing dependencies... it may take some time.\n"
    sudo apt-get update
    sudo apt-get install -y wget tar make cmake  bzip2 xz-utils g++ zlib1g-dev git |& tee -a "$LOG_FILE"
    buildGCC |& tee -a "$LOG_FILE"
	configureAndInstall |& tee -a "$LOG_FILE"
    ;;
"ubuntu-18.04")
    printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" "$DISTRO" |& tee -a "$LOG_FILE"
    printf -- "Installing dependencies... it may take some time.\n"
    sudo apt-get update
    sudo apt-get install -y build-essential wget make tar git cmake gcc-7 g++-7 |& tee -a "$LOG_FILE"
    sudo rm -rf /usr/bin/gcc /usr/bin/g++ /usr/bin/cc
	sudo ln -sf /usr/bin/gcc-7 /usr/bin/gcc
	sudo ln -sf /usr/bin/g++-7 /usr/bin/g++
	sudo ln -sf /usr/bin/gcc /usr/bin/cc
	configureAndInstall |& tee -a "$LOG_FILE"
	;;
"ubuntu-19.10")
    printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" "$DISTRO" |& tee -a "$LOG_FILE"
    printf -- "Installing dependencies... it may take some time.\n"
    sudo apt-get update
    sudo apt-get install -y wget tar make gcc-7 g++-7 cmake git |& tee -a "$LOG_FILE"
    sudo rm -rf /usr/bin/gcc /usr/bin/g++ /usr/bin/cc
    sudo ln -sf /usr/bin/gcc-7 /usr/bin/gcc
    sudo ln -sf /usr/bin/g++-7 /usr/bin/g++
    sudo ln -sf /usr/bin/gcc /usr/bin/cc
    configureAndInstall |& tee -a "$LOG_FILE"
	;;

"rhel-6.x")
    printf -- "Rhel 6.x is not supported !!. %s %s for %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" "$DISTRO" |& tee -a "$LOG_FILE"
    exit 1
    ;;
"rhel-7.5" | "rhel-7.6" | "rhel-7.7")
    printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" "$DISTRO" |& tee -a "$LOG_FILE"
    printf -- "Installing dependencies... it may take some time.\n"
    sudo yum install -y wget tar make gcc gcc-c++ bzip2 zlib zlib-devel git |& tee -a "$LOG_FILE"
    buildGCC |& tee -a "$LOG_FILE"
	configureAndInstall |& tee -a "$LOG_FILE"
    ;;
"rhel-8.0")
    printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" "$DISTRO" |& tee -a "$LOG_FILE"
    printf -- "Installing dependencies... it may take some time.\n"
    sudo yum install -y wget tar make gcc gcc-c++ bzip2 zlib zlib-devel git xz diffutils cmake |& tee -a "$LOG_FILE"
    buildGCC |& tee -a "$LOG_FILE"
	configureAndInstall |& tee -a "$LOG_FILE"
	;;
"sles-12.4")
    printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" "$DISTRO" |& tee -a "$LOG_FILE"
    printf -- "Installing dependencies... it may take some time.\n"
    sudo zypper install -y wget git tar cmake zlib-devel gcc7 gcc7-c++ |& tee -a "$LOG_FILE"
	sudo ln -sf /usr/bin/gcc-7 /usr/bin/gcc
    sudo ln -sf /usr/bin/g++-7 /usr/bin/g++
    sudo ln -sf /usr/bin/gcc /usr/bin/cc
    sudo ln -sf /usr/bin/gcc /usr/bin/s390x-linux-gnu-gcc
    configureAndInstall |& tee -a "$LOG_FILE"
    ;;
"sles-15.1")
    printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$GIT_BRANCH" "$DISTRO" |& tee -a "$LOG_FILE"
    printf -- "Installing dependencies... it may take some time.\n"
    sudo zypper install -y wget git tar cmake zlib-devel gcc gcc-c++ |& tee -a "$LOG_FILE"
	sudo ln -sf /usr/bin/gcc /usr/bin/s390x-linux-gnu-gcc
    configureAndInstall |& tee -a "$LOG_FILE"
    ;;
*)
    printf -- "%s not supported \n" "$DISTRO" |& tee -a "$LOG_FILE"
    exit 1
    ;;
esac
