#!/usr/bin/env bash
# © Copyright IBM Corporation 2020.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
#
# Instructions:
# Download build script: wget https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Docker/build_docker.sh
# You need a docker service running on your host before executing the script. 
# Execute build script: bash build_docker.sh    (provide -h for help)
​
set -e -o pipefail
​
PACKAGE_NAME="docker"
PACKAGE_VERSION="19.03.13"
CONTAINERD_VERSION="1.4.1"

##API KEY from the Service Credentials shared with read-write access. IAM Authentication is used here.
API_KEY="i5BcQeKf3I-wad0Uxx6rBfZKGIYO71LkV-q0UeDWO7t2"

##Name of the bucket in IBM Cloud Storage
BUCKET_NAME="test-bucket-nirman"

##Public Endpoint where bucket exists
PUBLIC_ENDPOINT="https://s3.us-south.cloud-object-storage.appdomain.cloud"


CURDIR="$(pwd)"
​
FORCE="false"
LOG_FILE="$CURDIR/logs/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
​
trap cleanup 0 1 2 ERR
​
#Check if directory exsists
if [ ! -d "$CURDIR/logs" ]; then
        mkdir -p "$CURDIR/logs"
fi
​
if [ -f "/etc/os-release" ]; then
        source "/etc/os-release"
fi
​
function checkPrequisites() {
        if command -v "sudo" >/dev/null; then
                printf -- 'Sudo : Yes\n' >>"$LOG_FILE"
        else
                printf -- 'Sudo : No \n' >>"$LOG_FILE"
                printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
                exit 1
        fi
​
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
​
function cleanup() {
        if [ -f ${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz ]; then
                sudo rm ${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz
        fi
}
​
function configureAndInstall() {
        printf -- 'Configuration and Installation started \n'
​
       # Download and Install Go
        cd /"$CURDIR"/
        wget https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Go/1.15/build_go.sh
		bash build_go.sh -y
​
        DISTRO=(xenial bionic focal)
        mkdir -p $CURDIR/go/src/github.com/docker
        cd $CURDIR/go/src/github.com/docker
        git clone https://github.com/docker/docker-ce
        cd docker-ce
        for DISTRO in "${DISTRO[@]}"
            do
            RASPBIAN_VERSIONS= UBUNTU_VERSIONS= DEBIAN_VERSIONS=ubuntu-$DISTRO make VERSION=$PACKAGE_VERSION deb
            done
​
​
        ## Build Containerd binaries
        cd $CURDIR/go/src/github.com/docker
        git clone https://github.com/docker/containerd-packaging
        cd containerd-packaging
		DISTRO=(xenial bionic focal)
        for DISTRO in "${DISTRO[@]}"
            do
            make REF=v$CONTAINERD_VERSION docker.io/library/ubuntu:$DISTRO
            done
​
​
        #Building Static Binaries
       
        cd $CURDIR/go/src/github.com/docker/docker-ce/components/packaging/static
        make VERSION=$PACKAGE_VERSION static-linux
​
}
​
function uploadBinaries() {
		printf -- '**************************** Starting to Upload Binaries *************************************************************\n' >"$LOG_FILE"
		#Create IAM Token for Authentication
		IAM_CREDS=$(curl -X "POST" "https://iam.cloud.ibm.com/identity/token" -H 'Accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode "apikey=$API_KEY" --data-urlencode "response_type=cloud_iam" --data-urlencode "grant_type=urn:ibm:params:oauth:grant-type:apikey")
		export IAM_TOKEN=$(jq -r '.access_token' <<< ${IAM_CREDS})
		
		##Uploading Ubuntu debs
		DISTRO=(xenial bionic focal)
		for DISTRO in "${DISTRO[@]}"
        do
			FILE_PATH=$CURDIR/go/src/github.com/docker/docker-ce/components/packaging/deb/debbuild/ubuntu-$DISTRO
			BINARY_PATH=linux/ubuntu/dists/$DISTRO/stable
			cd $FILE_PATH
			shopt -s nullglob
			for file_name in *.deb
			do
				echo "Uploading file $file_name\n"
				curl -X PUT "$PUBLIC_ENDPOINT/$BUCKET_NAME/$BINARY_PATH/$file_name" -H "x-amz-acl: public-read" -H "Authorization: Bearer $IAMTOK"  -T "$file_name"
			done
			shopt -u nullglob
        done
		
		##Uploading Static Binaries
		FILE_PATH=$CURDIR/go/src/github.com/docker/docker-ce/components/packaging/static/build/linux/
		BINARY_PATH=linux/static/s390x
		cd $FILE_PATH
		shopt -s nullglob
		for file_name in *.tgz
		do
			echo "Uploading file $file_name\n"
			curl -X PUT "$PUBLIC_ENDPOINT/$BUCKET_NAME/$BINARY_PATH/$file_name" -H "x-amz-acl: public-read" -H "Authorization: Bearer $IAMTOK"  -T "$file_name"
		done
		shopt -u nullglob
}

function logDetails() {
        printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"
​
        if [ -f "/etc/os-release" ]; then
                cat "/etc/os-release" >>"$LOG_FILE"
        fi
​
        cat /proc/version >>"$LOG_FILE"
        printf -- '*********************************************************************************************************\n' >>"$LOG_FILE"
​
        printf -- "Detected %s \n" "$PRETTY_NAME"
        printf -- "Request details : PACKAGE NAME= %s , VERSION= %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" |& tee -a "$LOG_FILE"
}
​
# Print the usage message
function printHelp() {
        echo
        echo "Usage: "
        echo "  build_docker.sh [-d debug]  [-y install-without-confirmation] "
        echo
}
​
while getopts "h?yd" opt; do
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
        esac
done
​
function gettingStarted() {
​
        printf -- "*************************************************************************"
        printf -- "\n\nUsage: \n"
        printf -- "  Docker Binaries installed successfully !!!  \n"
		
		printf -- "\n ***********Binaries will be created in the following folders************* \n "
		printf -- "\n ************************************************************************ \n "
		printf -- "\$CURDIR/go/src/github.com/docker/docker-ce/components/packaging/static/build/linux/docker \n"
		printf -- "\$CURDIR/go/src/github.com/docker/docker-ce/components/packaging/deb/debbuild \n "
		printf -- "\$CURDIR/go/src/github.com/docker/containerd-packaging/build/ubuntu \n "
        printf -- "\n************************************************************************** \n"
		
		printf -- "For building containerd binaries you should first have a tagged release on the containerd(https://github.com/containerd/containerd/releases) repository."
        printf -- '\n'
}
​
###############################################################################################################
​
logDetails
checkPrequisites #Check Prequisites
​
DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-18.04" | "ubuntu-20.04")
        printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
        printf -- 'Installing the dependencies for Docker from repository \n' |& tee -a "$LOG_FILE"
		sudo apt-get update -y >/dev/null
        sudo apt-get install -y wget tar make jq docker.io |& tee -a "$LOG_FILE"
		sudo chmod 666 /var/run/docker.sock
        configureAndInstall |& tee -a "$LOG_FILE"
		uploadBinaries |& tee -a "$LOG_FILE"
        ;;
*)
        printf -- "%s not supported \n" "$DISTRO" |& tee -a "$LOG_FILE"
        exit 1
        ;;
esac
​
gettingStarted |& tee -a "$LOG_FILE"