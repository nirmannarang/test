#!/bin/bash
# © Copyright IBM Corporation 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

################################################################################################################################################################
#Script     :   build_Calico.sh
#Description:   The script builds Calico version v3.2.3 on Linux on IBM Z for Rhel(7.3, 7.4, 7.5), Ubuntu(16.04, 18.04) and SLES(12SP3, 15).
#Maintainer :   LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource) 
#Info/Notes :   Please refer to the instructions first for Building Calico mentioned in wiki( https://github.com/linux-on-ibm-z/docs/wiki/Building-Calico-3.x ).
#               Build logs can be found in $HOME/Calico_v3.2.3/logs/ . Test logs can be found at $HOME/Calico_v3.2.3/logs/testLog-DATE-TIME.log.
#               By Default, system tests are turned off. To run system tests for Calico, pass argument "-t" to shell script.
#Download build script :   wget https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/calico/build_Calico.sh
#Run build script      :   bash build_Calico.sh       #(To only build Calico, provide -h for help)
#                          bash build_Calico.sh -t    #(To build Calico and run system tests)
#               
################################################################################################################################################################

### 1. Determine if Calico system tests are to be run
set -e
FORCE="false"
TESTS="false"

# Print the usage message
function printHelp() {
	echo
	echo "Usage: "
	echo "  build_Calico.sh  [-d debug] [-y build-without-confirmation] [-t build-with-tests]"
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

PACKAGE_NAME="Calico"
PACKAGE_VERSION="v3.2.3"

cd $HOME
#Check if directory exists
if [ ! -d "${PACKAGE_NAME}_${PACKAGE_VERSION}" ]; then
   mkdir -p "${PACKAGE_NAME}_${PACKAGE_VERSION}"
fi
export WORKDIR=${HOME}/${PACKAGE_NAME}_${PACKAGE_VERSION}
cd $WORKDIR

if [ ! -d "${WORKDIR}/logs" ]; then
   mkdir -p "${WORKDIR}/logs"
fi
export LOGDIR=${WORKDIR}/logs
#Create configuration log file
export CONF_LOG="${LOGDIR}/configuration-$(date +"%F-%T").log"
touch $CONF_LOG
PATCH_URL="https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Calico/patch"
GO_INSTALL_URL="https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Go/build_go.sh"
GO_DEFAULT="$HOME/go"
GO_FLAG="DEFAULT"


if [[ "$TESTS" == "true" ]]
then
	printf -- "TEST Flag is set , System tests will also run after Calico node build is complete. \n" | tee -a "$CONF_LOG"
else
	printf -- "System tests won't run for Calico by default \n"
fi

if [[ "$FORCE" == "true" ]]; then
	printf -- 'Force attribute provided hence continuing with Docker installation without confirmation message\n' | tee -a "$CONF_LOG"
else
	# Ask user for prerequisite installation
	printf -- "\nAs part of the installation, Docker will be installed. \n" | tee -a "$CONF_LOG"
	while true; do
		read -r -p "Do you want to continue (y/n) ? :  " yn
		case $yn in
		[Yy]*)
			printf -- 'User responded with Yes. \n' >> "$CONF_LOG"
			break
			;;
		[Nn]*) exit ;;
		*) echo "Please provide confirmation to proceed." ;;
		esac
	done
fi


### 2. Install the system dependencies
. /etc/os-release
if [[ "$ID" == "rhel" ]]; then
    printf -- "\nInstalling system dependencies . . . \n" | tee -a "$CONF_LOG"
	sudo yum install -y curl git wget tar gcc glibc-static.s390x make which patch | tee -a "$CONF_LOG"
	export CC=gcc
    printf -- "\nChecking if Docker is already present on the system . . . \n" | tee -a "$CONF_LOG"
	if [ -x "$(command -v docker)" ]; then
		docker --version | grep "Docker version" | tee -a "$CONF_LOG"
		echo "Docker already exists !! Skipping Docker Installation." | tee -a "$CONF_LOG"
		docker ps | tee -a "$CONF_LOG"
	else
		echo "Installing Docker !!"
		rm -rf docker-18.06.1-ce.tgz docker
		wget https://download.docker.com/linux/static/stable/s390x/docker-18.06.1-ce.tgz | tee -a "$CONF_LOG"
		tar xvf docker-18.06.1-ce.tgz | tee -a "$CONF_LOG"
		sudo cp docker/* /usr/local/bin/ | tee -a "$CONF_LOG"
cat << 'EOF' > docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target docker.socket
Requires=docker.socket

[Service]
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
#EnvironmentFile=/etc/sysconfig/docker
PIDFile=/var/run/docker.pid
ExecStart=/usr/local/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 -G docker
MountFlags=slave
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

[Install]
WantedBy=multi-user.target
EOF
cat << 'EOF' > docker.socket
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
# A Socket(User|Group) replacement workaround for systemd <= 214
#ExecStartPost=/usr/bin/chown root:docker /var/run/docker.sock

[Install]
WantedBy=sockets.target
EOF
		sudo mv docker.service /etc/systemd/system/
		sudo mv docker.socket /etc/systemd/system/
		sudo systemctl daemon-reload
		sudo systemctl enable docker
		sudo systemctl start docker | tee -a "$CONF_LOG"
		sleep 120s
		sudo chmod ugo+rw /var/run/docker.sock
		if [ `sudo systemctl is-active docker` = "active" ]
		then
		    echo "Docker service is active" | tee -a "$CONF_LOG"
        else
		    echo "Docker service is not active" | tee -a "$CONF_LOG"
			echo "Please check \"systemctl status docker.service\" for the logs" | tee -a "$CONF_LOG"
			exit 1
		fi
		docker ps
	fi
elif [[ "$ID" == "sles" ]]; then
    printf -- "\nInstalling system dependencies . . . \n" | tee -a "$CONF_LOG"
	sudo zypper install -y curl git wget tar gcc glibc-static.s390x make which patch | tee -a "$CONF_LOG"
	export CC=gcc
    printf -- "\nChecking if Docker is already present on the system . . . \n" | tee -a "$CONF_LOG"
	if [ -x "$(command -v docker)" ]; then
		docker --version | grep "Docker version" | tee -a "$CONF_LOG"
		echo "Docker already exists !! Skipping Docker Installation." | tee -a "$CONF_LOG"
		docker ps | tee -a "$CONF_LOG"
	else
		echo "Installing Docker !!"
		rm -rf docker-18.06.1-ce.tgz docker
		wget https://download.docker.com/linux/static/stable/s390x/docker-18.06.1-ce.tgz | tee -a "$CONF_LOG"
		tar xvf docker-18.06.1-ce.tgz | tee -a "$CONF_LOG"
		sudo cp docker/* /usr/local/bin/ | tee -a "$CONF_LOG"
cat << 'EOF' > docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target docker.socket
Requires=docker.socket

[Service]
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
#EnvironmentFile=/etc/sysconfig/docker
PIDFile=/var/run/docker.pid
ExecStart=/usr/local/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 -G docker
MountFlags=slave
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

[Install]
WantedBy=multi-user.target
EOF
cat << 'EOF' > docker.socket
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
# A Socket(User|Group) replacement workaround for systemd <= 214
#ExecStartPost=/usr/bin/chown root:docker /var/run/docker.sock

[Install]
WantedBy=sockets.target
EOF
		sudo mv docker.service /etc/systemd/system/
		sudo mv docker.socket /etc/systemd/system/
		sudo systemctl daemon-reload
		sudo systemctl enable docker
		sudo systemctl start docker | tee -a "$CONF_LOG"
		sleep 120s
		sudo chmod ugo+rw /var/run/docker.sock
		if [ `sudo systemctl is-active docker` = "active" ]
		then
		    echo "Docker service is active" | tee -a "$CONF_LOG"
        else
		    echo "Docker service is not active" | tee -a "$CONF_LOG"
			echo "Please check \"systemctl status docker.service\" for the logs" | tee -a "$CONF_LOG"
			exit 1
		fi
		docker ps
	fi
elif [[ "$ID" == "ubuntu" ]]; then
    printf -- "\nInstalling system dependencies . . . \n" | tee -a "$CONF_LOG"
	sudo apt-get update && sudo apt-get install -y git curl tar gcc wget make patch apt-transport-https  ca-certificates  curl software-properties-common | tee -a "$CONF_LOG"
    printf -- "\nChecking if Docker is already present on the system . . . \n" | tee -a "$CONF_LOG"
	if [ -x "$(command -v docker)" ]; then 
		docker --version | grep "Docker version" | tee -a "$CONF_LOG"
		echo "Docker already exists !! Skipping Docker Installation." | tee -a "$CONF_LOG"
		docker ps | tee -a "$CONF_LOG"
	else
		echo "Installing Docker !!"
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
		sudo add-apt-repository "deb [arch=s390x] https://download.docker.com/linux/ubuntu artful stable" | tee -a "$CONF_LOG"
		sudo apt-get update
		sudo apt-get install -y docker-ce | tee -a "$CONF_LOG"
		sudo systemctl enable docker
		sudo systemctl start docker | tee -a "$CONF_LOG"
		sleep 120s
		sudo chmod ugo+rw /var/run/docker.sock
		if [ `sudo systemctl is-active docker` = "active" ]
		then
		    echo "Docker service is active" | tee -a "$CONF_LOG"
        else
		    echo "Docker service is not active" | tee -a "$CONF_LOG"
			echo "Please check \"systemctl status docker.service\" for the logs" | tee -a "$CONF_LOG"
			exit 1
		fi
		docker ps | tee -a "$CONF_LOG"
	fi
fi


#### 3. Install `Go` and  `etcd` as prerequisites
if [[ "$FORCE" == "true" ]]; then
	printf -- 'Force attribute provided hence continuing with install without confirmation message\n' | tee -a "$CONF_LOG"
else
	# Ask user for prerequisite installation
	printf -- "\nAs part of the installation, Go 1.10.1 will be installed. \n" | tee -a "$CONF_LOG"
	while true; do
		read -r -p "Do you want to continue (y/n) ? :  " yn
		case $yn in
		[Yy]*)
			printf -- 'User responded with Yes. \n' >> "$CONF_LOG"
			break
			;;
		[Nn]*) exit ;;
		*) echo "Please provide confirmation to proceed." ;;
		esac
	done
fi
### 3.1 Install `Go 1.10.1`
printf -- '\nConfiguration and Installation started \n' | tee -a "$CONF_LOG"

# Install go
printf -- "\nInstalling Go . . . \n"  | tee -a "$CONF_LOG"
curl -s  $GO_INSTALL_URL | sudo bash


# Set GOPATH if not already set
if [[ -z "${GOPATH}" ]]; then
	printf -- "\nSetting default value for GOPATH \n"
	#Check if go directory exists
	if [ ! -d "$HOME/go" ]; then
		mkdir "$HOME/go"
	fi
	export GOPATH="${GO_DEFAULT}"
else
	printf -- "\nGOPATH already set : Value : %s \n" "$GOPATH"
	export GO_FLAG="CUSTOM"
fi

export PATH=$GOPATH/bin:$PATH


### 3.2 Install `etcd v3.3.7`.
printf -- "\nInstalling etcd v3.3.7 . . . \n"  | tee -a "$CONF_LOG"
cd $GOPATH 
mkdir -p $GOPATH/src/github.com/coreos
mkdir -p $GOPATH/etcd_temp
cd $GOPATH/src/github.com/coreos
rm -rf etcd
git clone git://github.com/coreos/etcd | tee -a "$CONF_LOG"
cd etcd
git checkout v3.3.7 | tee -a "$CONF_LOG"
export ETCD_DATA_DIR=$GOPATH/etcd_temp
export ETCD_UNSUPPORTED_ARCH=s390x
printf -- "\nBuilding . . . \n"  | tee -a "$CONF_LOG"
./build

printenv >> "$CONF_LOG"

#### 4. Build `calicoctl` and  `calico/node` image
export GOBUILD_LOG="${LOGDIR}/go-build-$(date +"%F-%T").log"
touch $GOBUILD_LOG
printf -- "\nBuilding go-build . . . \n"  | tee -a "$GOBUILD_LOG"
### 4.1 Build `go-build`
##This builds a docker image calico/go-build that is used to build other components
rm -rf $GOPATH/src/github.com/projectcalico/go-build
git clone https://github.com/projectcalico/go-build $GOPATH/src/github.com/projectcalico/go-build | tee -a "$GOBUILD_LOG"
cd $GOPATH/src/github.com/projectcalico/go-build
git checkout v0.17 | tee -a "$GOBUILD_LOG"

## Then  build `calico/go-build-s390x` image
ARCH=s390x make build 2>&1 | tee -a "$GOBUILD_LOG"
if grep -Fxq "Successfully tagged calico/go-build:latest-s390x" $GOBUILD_LOG
then
    echo "Successfully built calico/go-build" | tee -a "$GOBUILD_LOG"
else
    echo "go-build FAILED, Stopping further build !!! Check logs at $GOBUILD_LOG" | tee -a "$GOBUILD_LOG"
	exit 1
fi

docker tag calico/go-build:latest-s390x calico/go-build-s390x:latest 
docker tag calico/go-build:latest-s390x calico/go-build:latest
docker tag calico/go-build:latest-s390x calico/go-build:v0.17

### 4.2 Build `calicoctl` binary and `calico/ctl` image
export CALICOCTL_LOG="${LOGDIR}/calicoctl-$(date +"%F-%T").log"
touch $CALICOCTL_LOG
printf -- "\nBuilding calicoctl . . . \n"  | tee -a "$CALICOCTL_LOG"
## Download the source code
rm -rf $GOPATH/src/github.com/projectcalico/calicoctl
git clone https://github.com/projectcalico/calicoctl $GOPATH/src/github.com/projectcalico/calicoctl | tee -a "$CALICOCTL_LOG"
cd $GOPATH/src/github.com/projectcalico/calicoctl 
git checkout v3.2.3 | tee -a "$CALICOCTL_LOG"

## Build the `calicoctl` binary and `calico/ctl` image
ARCH=s390x make calico/ctl 2>&1 | tee -a "$CALICOCTL_LOG"

if grep -Fxq "Successfully tagged calico/ctl:latest-s390x" $CALICOCTL_LOG
then
    echo "Successfully built calico/ctl" | tee -a "$CALICOCTL_LOG"
else
    echo "calico/ctl Build FAILED, Stopping further build !!! Check logs at $CALICOCTL_LOG" | tee -a "$CALICOCTL_LOG"
	exit 1
fi


### 4.3 Build `bird`
export BIRD_LOG="${LOGDIR}/bird-$(date +"%F-%T").log"
touch $BIRD_LOG
printf -- "\nBuilding bird . . . \n"  | tee -a "$BIRD_LOG"
## Download the source code
sudo rm -rf $GOPATH/src/github.com/projectcalico/bird
git clone https://github.com/projectcalico/bird $GOPATH/src/github.com/projectcalico/bird | tee -a "$BIRD_LOG"
cd $GOPATH/src/github.com/projectcalico/bird 
git checkout v0.3.2 | tee -a "$BIRD_LOG"

## Create `Dockerfile-s390x`
cat << 'EOF' > Dockerfile-s390x
FROM s390x/alpine:3.8
MAINTAINER LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource)

RUN apk update
RUN apk add alpine-sdk linux-headers autoconf flex bison ncurses-dev readline-dev

WORKDIR /code
EOF

## Modify `build.sh`, patching build.sh file
printf -- "\nDownloading patch for bird . . . \n"  | tee -a "$BIRD_LOG"
curl  -o "bird_build.sh.diff" $PATCH_URL/bird_build.sh.diff | tee -a "$BIRD_LOG"
printf -- "\nApplying patch to build.sh . . . \n"  | tee -a "$BIRD_LOG"
patch build.sh bird_build.sh.diff | tee -a "$BIRD_LOG"
rm -rf bird_build.sh.diff

## Run `build.sh` to build 3 executable files (in `dist/s390x/`)
ARCH=s390x ./build.sh 2>&1 | tee -a "$BIRD_LOG"
if [[ "$(docker images -q birdbuild-s390x:latest 2> /dev/null)" == "" ]]; then
  echo "Bird build FAILED, Stopping further build !!! Check logs at $BIRD_LOG" | tee -a "$BIRD_LOG"
  exit 1
else
  echo "Successfully built bird module." | tee -a "$BIRD_LOG"
fi
## Tag calico/bird image
docker tag birdbuild-s390x:latest calico/bird:v0.3.2-s390x
docker tag birdbuild-s390x:latest calico/bird:latest

                   
### 4.4 Build `Typha`
export TYPHA_LOG="${LOGDIR}/typha-$(date +"%F-%T").log"
touch $TYPHA_LOG
printf -- "\nBuilding typha . . . \n"  | tee -a "$TYPHA_LOG"
## Download the source code
rm -rf $GOPATH/src/github.com/projectcalico/typha
git clone https://github.com/projectcalico/typha $GOPATH/src/github.com/projectcalico/typha | tee -a "$TYPHA_LOG"
cd $GOPATH/src/github.com/projectcalico/typha 
git checkout v3.2.3 | tee -a "$TYPHA_LOG"

## Modify `Makefile`, patching Makefile
printf -- "\nDownloading patch for typha Makefile . . . \n"  | tee -a "$TYPHA_LOG"
curl  -o "typha_makefile.diff" $PATCH_URL/typha_makefile.diff | tee -a "$TYPHA_LOG"
printf -- "\nApplying patch to Makefile . . . \n"  | tee -a "$$TYPHA_LOG"
patch Makefile typha_makefile.diff | tee -a "$TYPHA_LOG"
rm -rf typha_makefile.diff

## Modify `docker-image/Dockerfile.s390x`, patching Dockerfile.s390x
cd docker-image
printf -- "\nDownloading patch for typha Dockerfile.s390x . . . \n"  | tee -a "$TYPHA_LOG"
curl  -o "typha_dockerfile.diff" $PATCH_URL/typha_dockerfile.diff | tee -a "$TYPHA_LOG"
printf -- "\nApplying patch to Dockerfile.s390x . . . \n"  | tee -a "$TYPHA_LOG"
patch Dockerfile.s390x typha_dockerfile.diff | tee -a "$TYPHA_LOG"
rm -rf typha_dockerfile.diff

## Build the binaries and docker image for typha
cd $GOPATH/src/github.com/projectcalico/typha
ARCH=s390x make calico/typha 2>&1 | tee -a "$TYPHA_LOG"

if grep -Fxq "Successfully tagged calico/typha:latest-s390x" $TYPHA_LOG
then
    echo "Successfully built calico/typha" | tee -a "$TYPHA_LOG"
else
    echo "calico/typha Build FAILED, Stopping further build !!! Check logs at $TYPHA_LOG" | tee -a "$TYPHA_LOG"
	exit 1
fi

### 4.5 Build `felix`
## To build `felix` it  needs `felixbackend.pb.go` that is generated by a docker image `calico/protoc`. Let's first built this image.
export PROTO_LOG="${LOGDIR}/docker-protobuf-$(date +"%F-%T").log"
touch $PROTO_LOG
printf -- "\nBuilding docker-protobuf . . . \n"  | tee -a "$PROTO_LOG"
rm -rf $GOPATH/src/github.com/projectcalico/docker-protobuf
git clone https://github.com/tigera/docker-protobuf $GOPATH/src/github.com/projectcalico/docker-protobuf | tee -a "$PROTO_LOG"
cd  $GOPATH/src/github.com/projectcalico/docker-protobuf

## Modify `Dockerfile-s390x`, patching the same
printf -- "\nDownloading patch for docker-protobuf Dockerfile-s390x . . . \n"  | tee -a "$PROTO_LOG"
curl  -o "protobuf_dockerfile.diff" $PATCH_URL/protobuf_dockerfile.diff | tee -a "$PROTO_LOG"
printf -- "\nApplying patch to Dockerfile-s390x . . . \n"  | tee -a "$PROTO_LOG"
patch Dockerfile-s390x protobuf_dockerfile.diff | tee -a "$PROTO_LOG"
rm -rf protobuf_dockerfile.diff

## Build and tag docker image `calico/protoc-s390x`
docker build -t calico/protoc-s390x -f Dockerfile-s390x . 2>&1 | tee -a "$PROTO_LOG"
if grep -Fxq "Successfully tagged calico/protoc-s390x:latest" $PROTO_LOG
then
    echo "Successfully built calico/protoc-s390x" | tee -a "$PROTO_LOG"
else
    echo "calico/protoc Build FAILED, Stopping further build !!! Check logs at $PROTO_LOG" | tee -a "$PROTO_LOG"
	exit 1
fi

docker tag calico/protoc-s390x:latest calico/protoc:latest-s390x


### Build `felix`
export FELIX_LOG="${LOGDIR}/felix-$(date +"%F-%T").log"
touch $FELIX_LOG
printf -- "\nBuilding felix . . . \n"  | tee -a "$FELIX_LOG"
git clone https://github.com/projectcalico/felix $GOPATH/src/github.com/projectcalico/felix | tee -a "$FELIX_LOG"
cd $GOPATH/src/github.com/projectcalico/felix
git checkout v3.2.3 | tee -a "$FELIX_LOG"

## Modify Makefile, patching the same
printf -- "\nDownloading patch for felix Makefile . . . \n"  | tee -a "$FELIX_LOG"
curl  -o "felix_makefile.diff" $PATCH_URL/felix_makefile.diff | tee -a "$FELIX_LOG"
printf -- "\nApplying patch to Makefile . . . \n"  | tee -a "$FELIX_LOG"
patch Makefile felix_makefile.diff | tee -a "$FELIX_LOG"
rm -rf felix_makefile.diff

## Modify `docker-image/Dockerfile.s390x`
cd docker-image/
printf -- "\nDownloading patch for felix Dockerfile.s390x . . . \n"  | tee -a "$FELIX_LOG"
curl  -o "felix_dockerfile.diff" $PATCH_URL/felix_dockerfile.diff | tee -a "$FELIX_LOG"
printf -- "\nApplying patch to Dockerfile.s390x . . . \n"  | tee -a "$FELIX_LOG"
patch Dockerfile.s390x felix_dockerfile.diff | tee -a "$FELIX_LOG"
rm -rf felix_dockerfile.diff

## Build the felix binaries
cd $GOPATH/src/github.com/projectcalico/felix
ARCH=s390x make image 2>&1 | tee -a "$FELIX_LOG"

if grep -Fxq "Successfully tagged calico/felix:latest-s390x" $FELIX_LOG
then
    echo "Successfully built calico/felix" | tee -a "$FELIX_LOG"
else
    echo "calico/felix Build FAILED, Stopping further build !!! Check logs at $FELIX_LOG" | tee -a "$FELIX_LOG"
	exit 1
fi


### 4.6 Build `cni-plugin` binaries and image
export CNI_LOG="${LOGDIR}/cni-plugin-$(date +"%F-%T").log"
touch $CNI_LOG
printf -- "\nBuilding cni-plugin . . . \n"  | tee -a "$CNI_LOG"
## Download the source code
sudo mkdir -p /opt/cni/bin | tee -a "$CNI_LOG"
rm -rf $GOPATH/src/github.com/projectcalico/cni-plugin
git clone https://github.com/projectcalico/cni-plugin.git $GOPATH/src/github.com/projectcalico/cni-plugin | tee -a "$CNI_LOG"
cd $GOPATH/src/github.com/projectcalico/cni-plugin
git checkout v3.2.3 | tee -a "$CNI_LOG"

## Build binaries and image
ARCH=s390x make image 2>&1 | tee -a "$CNI_LOG"

if grep -Fxq "Successfully tagged calico/cni:latest-s390x" $CNI_LOG
then
    echo "Successfully built calico/cni-plugin" | tee -a "$CNI_LOG"
else
    echo "calico/cni-plugin Build FAILED, Stopping further build !!! Check logs at $CNI_LOG" | tee -a "$CNI_LOG"
	exit 1
fi

printf -- "\nCopying cni-plugin binaries to /opt/cni/bin . . . \n"  | tee -a "$CNI_LOG"
sudo cp bin/s390x/* /opt/cni/bin | tee -a "$CNI_LOG"
docker tag calico/cni:latest-s390x calico/cni:latest
docker tag calico/cni:latest quay.io/calico/cni-s390x:v3.2.3


### 4.7 Build image `calico/node`
export NODE_LOG="${LOGDIR}/node-$(date +"%F-%T").log"
touch $NODE_LOG
printf -- "\nBuilding Calico node . . . \n"  | tee -a "$NODE_LOG"
## Download the source
rm -rf $GOPATH/src/github.com/projectcalico/node
git clone https://github.com/projectcalico/node $GOPATH/src/github.com/projectcalico/node | tee -a "$NODE_LOG"
cd $GOPATH/src/github.com/projectcalico/node
git checkout v3.2.3 | tee -a "$NODE_LOG"

## Modify `Makefile`, patching the same
printf -- "\nDownloading patch for node Makefile . . . \n"  | tee -a "$NODE_LOG"
curl  -o "node_makefile.diff" $PATCH_URL/node_makefile.diff | tee -a "$NODE_LOG"
printf -- "\nApplying patch to Makefile . . . \n"  | tee -a "$NODE_LOG"
patch Makefile node_makefile.diff | tee -a "$NODE_LOG"
rm -rf node_makefile.diff

## Modify `Dockerfile.s390x`, patching the same
printf -- "\nDownloading patch for node Dockerfile.s390x . . . \n"  | tee -a "$NODE_LOG"
curl  -o "node_dockerfile.diff" $PATCH_URL/node_dockerfile.diff | tee -a "$NODE_LOG"
printf -- "\nApplying patch to Dockerfile.s390x . . . \n"  | tee -a "$NODE_LOG"
patch Dockerfile.s390x node_dockerfile.diff | tee -a "$NODE_LOG"
rm -rf node_dockerfile.diff

## Get the yaml binary if not installed, needed for building `calico/node`
printf -- "\nInstalling YAML binary . . . \n"  | tee -a "$CONF_LOG"
go get gopkg.in/mikefarah/yq.v1
cd $GOPATH/bin
if [[ -e yaml ]]
then
    printf -- "\nYaml binary exists. \n" | tee -a "$CONF_LOG"
else
    ln -s yq.v1 yaml | tee -a "$CONF_LOG"
fi
export PATH=$PATH:$GOPATH/bin

### Build `calico/node`
printf -- "\nCreating filesystem/bin and dist directories for keeping binaries . . . \n"  | tee -a "$NODE_LOG"
cd $GOPATH/src/github.com/projectcalico/node
mkdir -p filesystem/bin
mkdir -p dist
printf -- "\nCopying bird binaries . . . \n"  | tee -a "$NODE_LOG"
cp $GOPATH/src/github.com/projectcalico/bird/dist/s390x/* $GOPATH/src/github.com/projectcalico/node/filesystem/bin | tee -a "$NODE_LOG"
printf -- "\nCopying felix binaries . . . \n"  | tee -a "$NODE_LOG"
cp $GOPATH/src/github.com/projectcalico/felix/bin/calico-felix-s390x $GOPATH/src/github.com/projectcalico/node/filesystem/bin/calico-felix | tee -a "$NODE_LOG"
printf -- "\nCopying calicoctl binaries . . . \n"  | tee -a "$NODE_LOG"
cp $GOPATH/src/github.com/projectcalico/calicoctl/bin/calicoctl-linux-s390x $GOPATH/src/github.com/projectcalico/node/dist/calicoctl | tee -a "$NODE_LOG"

printf -- "\nBuilding calico/node Image . . . \n"  | tee -a "$NODE_LOG"
ARCH=s390x make calico/node 2>&1 | tee -a "$NODE_LOG"

if grep -Fxq "Successfully tagged calico/node:latest-s390x" $NODE_LOG
then
    echo "Successfully built calico/node" | tee -a "$NODE_LOG"
else
    echo "calico/node Build FAILED, Stopping further build !!! Check logs at $NODE_LOG" | tee -a "$NODE_LOG"
	exit 1
fi

docker tag calico/node:latest-s390x quay.io/calico/node-s390x:v3.2.3
docker tag calico/node:latest-s390x calico/node


#### 5. Calico testcases
### 5.1 Build `etcd`
export ETCD_LOG="${LOGDIR}/etcd-$(date +"%F-%T").log"
touch $ETCD_LOG
printf -- "\nBuilding etcd Image . . . \n"  | tee -a "$ETCD_LOG"
rm -rf $GOPATH/src/github.com/projectcalico/etcd
cd $GOPATH/src/github.com/projectcalico/
git clone https://github.com/coreos/etcd | tee -a "$ETCD_LOG"
cd etcd 
git checkout v3.3.7 | tee -a "$ETCD_LOG"

## Modify `Dockerfile-release` for s390x
printf -- "\nDownloading patch for etcd Dockerfile-release . . . \n"  | tee -a "$ETCD_LOG"
curl  -o "etcd_dockerfile.diff" $PATCH_URL/etcd_dockerfile.diff | tee -a "$ETCD_LOG"
printf -- "\nApplying patch to Dockerfile-release . . . \n"  | tee -a "$ETCD_LOG"
patch Dockerfile-release etcd_dockerfile.diff | tee -a "$ETCD_LOG"
rm -rf etcd_dockerfile.diff

## Then build etcd and image
./build | tee -a "$ETCD_LOG"
docker build -f Dockerfile-release  -t quay.io/coreos/etcd . 2>&1 | tee -a "$ETCD_LOG"

if grep -Fxq "Successfully tagged quay.io/coreos/etcd:latest" $ETCD_LOG
then
    echo "Successfully built etcd image" | tee -a "$ETCD_LOG"
else
    echo "etcd image Build FAILED, Stopping further build !!! Check logs at $ETCD_LOG" | tee -a "$ETCD_LOG"
	exit 1
fi

cd bin
printf -- "\nCreate a tar file containing etcd, etcdctl binaries . . . \n"  | tee -a "$ETCD_LOG"
tar cvf etcd-v3.3.7-linux-s390x.tar etcd etcdctl | tee -a "$ETCD_LOG"
printf -- "\nCompressing etcd tar file using gzip . . . \n"  | tee -a "$ETCD_LOG"
gzip etcd-v3.3.7-linux-s390x.tar | tee -a "$ETCD_LOG"
docker tag quay.io/coreos/etcd:latest quay.io/coreos/etcd:v3.3.7-s390x
docker tag quay.io/coreos/etcd quay.io/coreos/etcd:v3.3.7


### 5.2 Build `Confd` Image
export CONFD_LOG="${LOGDIR}/confd-$(date +"%F-%T").log"
touch $CONFD_LOG
printf -- "\nBuilding confd Image . . . \n"  | tee -a "$CONFD_LOG"
rm -rf $GOPATH/src/github.com/projectcalico/confd-v3.1.3
git clone https://github.com/projectcalico/confd $GOPATH/src/github.com/projectcalico/confd-v3.1.3 | tee -a "$CONFD_LOG"
cd $GOPATH/src/github.com/projectcalico/confd-v3.1.3
git checkout v3.1.3 | tee -a "$CONFD_LOG"
printf -- "\nCreating Dockerfile-s390x for confd Image . . . \n"  | tee -a "$CONFD_LOG"
## Create `Dockerfile-s390x`
cat << 'EOF' > Dockerfile-s390x
FROM s390x/alpine:3.6
MAINTAINER LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource)

# Copy in the binary.
ADD bin/confd /bin/confd
EOF

## Build confd image
cd $GOPATH/src/github.com/projectcalico/confd-v3.1.3
ARCH=s390x make container 2>&1 | tee -a "$CONFD_LOG"

if grep -Fxq "Successfully tagged calico/confd-s390x:latest" $CONFD_LOG
then
    echo "Successfully built calico/confd" | tee -a "$CONFD_LOG"
else
    echo "calico/confd Build FAILED, Stopping further build !!! Check logs at $CONFD_LOG" | tee -a "$CONFD_LOG"
	exit 1
fi

docker tag calico/confd-s390x:latest calico/confd:v3.1.1-s390x


### 5.3 Build `calico/routereflector`
export RREFLECTOR_LOG="${LOGDIR}/routereflector-$(date +"%F-%T").log"
touch $RREFLECTOR_LOG
printf -- "\nBuilding Routereflector . . . \n"  | tee -a "$RREFLECTOR_LOG"
rm -rf $GOPATH/src/github.com/projectcalico/routereflector
git clone https://github.com/projectcalico/routereflector.git $GOPATH/src/github.com/projectcalico/routereflector | tee -a "$RREFLECTOR_LOG"
cd $GOPATH/src/github.com/projectcalico/routereflector
git checkout v0.6.3 | tee -a "$RREFLECTOR_LOG"
printf -- "\nCopying bird binaries to image directory of Routereflector . . . \n"  | tee -a "$RREFLECTOR_LOG"
cp $GOPATH/src/github.com/projectcalico/bird/dist/s390x/* image/ | tee -a "$RREFLECTOR_LOG"

## Modify `Makefile`, patching the same
printf -- "\nDownloading patch for routereflector Makefile . . . \n"  | tee -a "$RREFLECTOR_LOG"
curl  -o "routereflector_makefile.diff" $PATCH_URL/routereflector_makefile.diff | tee -a "$RREFLECTOR_LOG"
printf -- "\nApplying patch to Makefile . . . \n"  | tee -a "$RREFLECTOR_LOG"
patch Makefile routereflector_makefile.diff | tee -a "$RREFLECTOR_LOG"
rm -rf routereflector_makefile.diff

## Build the routereflector 
cd $GOPATH/src/github.com/projectcalico/routereflector
ARCH=s390x make image 2>&1 | tee -a "$RREFLECTOR_LOG"

if grep -Fxq "Successfully tagged calico/routereflector:latest-s390x" $RREFLECTOR_LOG
then
    echo "Successfully built calico/routereflector" | tee -a "$RREFLECTOR_LOG"
else
    echo "calico/routereflector Build FAILED, Stopping further build !!! Check logs at $RREFLECTOR_LOG" | tee -a "$RREFLECTOR_LOG"
	exit 1
fi

docker tag calico/routereflector:latest-s390x calico/routereflector:latest


### 5.4 Build `calico/dind`
export DIND_LOG="${LOGDIR}/dind-$(date +"%F-%T").log"
touch $DIND_LOG
printf -- "\nBuilding dind Image for s390x . . . \n"  | tee -a "$DIND_LOG"
rm -rf $GOPATH/src/github.com/projectcalico/dind
git clone https://github.com/projectcalico/dind $GOPATH/src/github.com/projectcalico/dind | tee -a "$DIND_LOG"
cd $GOPATH/src/github.com/projectcalico/dind
## Build the dind
docker build -t calico/dind -f Dockerfile-s390x . 2>&1 | tee -a "$DIND_LOG"

if grep -Fxq "Successfully tagged calico/dind:latest" $DIND_LOG
then
    echo "Successfully built calico/dind" | tee -a "$DIND_LOG"
else
    echo "calico/dind Build FAILED, Stopping further build !!! Check logs at $DIND_LOG" | tee -a "$DIND_LOG"
	exit 1
fi


### 5.5 Build `calico_test`
export TEST_LOG="${LOGDIR}/testLog-$(date +"%F-%T").log"
touch $TEST_LOG
printf -- "\nMaking required changes to node/calico_test for s390x . . . \n"  | tee -a "$TEST_LOG"
cd $GOPATH/src/github.com/projectcalico/node/calico_test/
printf -- "\nCreating directory pkg . . . \n"  | tee -a "$TEST_LOG"
mkdir -p pkg
printf -- "\nCopying etcd tar file to pkg dir in calico_test . . . \n"  | tee -a "$TEST_LOG"
cp $GOPATH/src/github.com/projectcalico/etcd/bin/etcd-v3.3.7-linux-s390x.tar.gz pkg

## Create `Dockerfile.s390x.calico_test`
printf -- "\nCreating Dockerfile.s390x.calico_test . . . \n"  | tee -a "$TEST_LOG"
cat << 'EOF' > Dockerfile.s390x.calico_test
FROM s390x/docker:18.03.0
MAINTAINER LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource)

RUN apk add --update python python-dev py2-pip py-setuptools openssl-dev libffi-dev tshark \
        netcat-openbsd iptables ip6tables iproute2 iputils ipset curl && \
        echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
        rm -rf /var/cache/apk/*

COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

RUN apk update \
&&   apk add ca-certificates wget \
&&   update-ca-certificates

# Install etcdctl
COPY pkg /pkg/
RUN tar -xzf pkg/etcd-v3.3.7-linux-s390x.tar.gz -C /usr/local/bin/

# The container is used by mounting the code-under-test to /code
WORKDIR /code/
EOF


### 5.6 Run the test cases
#Pull s390x images for creating workload
printf -- "\nPulling s390x images for creating workload . . . \n"  | tee -a "$TEST_LOG"
docker pull s390x/busybox | tee -a "$TEST_LOG"
docker tag s390x/busybox busybox
docker pull s390x/nginx | tee -a "$TEST_LOG"
docker tag s390x/nginx nginx


## Create `Dockerfile.s390x`
printf -- "\nMaking required changes to node/workload for s390x . . . \n"  | tee -a "$TEST_LOG"
cd $GOPATH/src/github.com/projectcalico/node/workload
printf -- "\nCreating Dockerfile.s390x . . . \n"  | tee -a "$TEST_LOG"
cat << 'EOF' > Dockerfile.s390x
FROM s390x/alpine:3.8
RUN apk add --no-cache \
    python \
    netcat-openbsd
COPY udpping.sh tcpping.sh responder.py /code/
WORKDIR /code/
RUN chmod +x udpping.sh && chmod +x tcpping.sh
CMD ["python", "responder.py"]
EOF


#Verifying if all images are built/tagged
export VERIFY_LOG="${LOGDIR}/verify-images-$(date +"%F-%T").log"
touch $VERIFY_LOG
printf -- "\nVerifying if all needed images are successfully built/downloaded ? . . . \n"  | tee -a "$VERIFY_LOG"
cd $WORKDIR
echo "Required Docker Images: " >> $VERIFY_LOG
cat << 'EOF' > docker_images_expected.txt
calico/dind:latest
calico/routereflector:latest
calico/routereflector:latest-s390x
calico/confd-s390x:latest
calico/confd:v3.1.1-s390x
quay.io/coreos/etcd:latest
quay.io/coreos/etcd:v3.3.7
quay.io/coreos/etcd:v3.3.7-s390x
calico/node:latest
calico/node:latest-s390x
quay.io/calico/node-s390x:v3.2.3
quay.io/calico/cni-s390x:v3.2.3
calico/cni:latest
calico/cni:latest-s390x
calico/felix:latest-s390x
calico/protoc-s390x:latest
calico/protoc:latest-s390x
calico/typha:latest-s390x
calico/bird:latest
calico/bird:v0.3.2-s390x
birdbuild-s390x:latest
calico/ctl:latest-s390x
calico/go-build:latest
calico/go-build:latest-s390x
calico/go-build:v0.17
calico/go-build-s390x:latest
EOF

cat docker_images_expected.txt >> $VERIFY_LOG
docker images --format "{{.Repository}}:{{.Tag}}" > docker_images.txt
echo "" >> $VERIFY_LOG
echo "" >> $VERIFY_LOG
echo "Images present: " >> $VERIFY_LOG
echo "########################################################################" >> $VERIFY_LOG
echo "########################################################################" >> $VERIFY_LOG
cat docker_images_expected.txt >> $VERIFY_LOG
count=0
while read image; do
  if ! grep -q $image docker_images.txt; then
  echo ""
  echo "$image" | tee -a "$VERIFY_LOG"
  count=`expr $count + 1`
  fi
done < docker_images_expected.txt
if [ "$count" != "0" ]; then
	echo "" | tee -a "$VERIFY_LOG"
	echo "" | tee -a "$VERIFY_LOG"
	echo "Above $count images need to be present. Check $VERIFY_LOG and the logs of above images/modules in $LOGDIR" | tee -a "$VERIFY_LOG"
	echo "CALICO NODE & TESTS BUILD FAILED !!" | tee -a "$VERIFY_LOG"
	exit 1
else
	echo "" | tee -a "$VERIFY_LOG"
	echo "" | tee -a "$VERIFY_LOG"
	echo "" | tee -a "$VERIFY_LOG"
	echo "###################-----------------------------------------------------------------------------------------------###################" | tee -a "$VERIFY_LOG"
	echo "                                      All docker images are created as expected." | tee -a "$VERIFY_LOG"
	echo ""
	echo "                                  CALICO NODE & TESTS BUILD COMPLETED SUCCESSFULLY !!" | tee -a "$VERIFY_LOG"
	echo "###################-----------------------------------------------------------------------------------------------###################" | tee -a "$VERIFY_LOG"
fi
rm -rf docker_images_expected.txt docker_images.txt
##########################################################################################################################################################
##########################################################################################################################################################
#                                              CALICO NODE & TESTS BUILD COMPLETED SUCCESSFULLY                                                          #
##########################################################################################################################################################
##########################################################################################################################################################

## 4.6.2 Execute test cases(Optional)
#Will only run if arg "-t" is passed to shell script
if [[ "$TESTS" == "true" ]]
then
    printf -- "##############-----------------------------------------------------------------------------------------------############## \n" | tee -a "$TEST_LOG" 
    printf -- "                             TEST Flag is set , Running system tests now. \n" | tee -a "$TEST_LOG" 
    printf -- "                            Testlogs are saved in $TEST_LOG \n" | tee -a "$TEST_LOG" 
    printf -- "##############-----------------------------------------------------------------------------------------------############## \n" | tee -a "$TEST_LOG" 
    cd $GOPATH/src/github.com/projectcalico/node
    ARCH=s390x make st 2>&1 | tee -a "$TEST_LOG" 
else
    set +x
    cd $GOPATH
    printf -- "------------------------------------------------------------------------------------------------------------------- \n" | tee -a "$TEST_LOG" 
    printf -- "       System tests won't run for Calico by default as \"-t\" was not passed to this script in beginning. \n" | tee -a "$TEST_LOG" 
    printf -- "------------------------------------------------------------------------------------------------------------------- \n" | tee -a "$TEST_LOG" 
    printf -- " \n" | tee -a "$TEST_LOG" 
    printf -- " \n" | tee -a "$TEST_LOG" 
    printf -- "                        To run Calico system tests, run the following commands now: \n" | tee -a "$TEST_LOG" 
    printf -- "------------------------------------------------------------------------------------------------------------------- \n" | tee -a "$TEST_LOG" 
	printf -- "                       PACKAGE_NAME=\"Calico\" \n" | tee -a "$TEST_LOG" 
    printf -- "                       PACKAGE_VERSION=\"v3.2.3\" \n" | tee -a "$TEST_LOG" 
	printf -- "                       export WORKDIR=\${HOME}/\${PACKAGE_NAME}_\${PACKAGE_VERSION} \n" | tee -a "$TEST_LOG" 
	printf -- "                       export LOGDIR=\${WORKDIR}/logs \n" | tee -a "$TEST_LOG" 
	if [[ "$GO_FLAG" == "DEFAULT" ]]
	then
	    printf -- "                  ##   Set default value for GOPATH \n" | tee -a "$TEST_LOG" 
	    printf -- "                       export GOPATH=\$HOME/go \n" | tee -a "$TEST_LOG" 
    else
	    printf -- "                  ##   GOPATH already set in the system : Value : %s \n" "$GOPATH" | tee -a "$TEST_LOG" 
    fi
    printf -- "                       export PATH=\$GOPATH/bin:\$PATH \n" | tee -a "$TEST_LOG" 
    printf -- "                       export ETCD_DATA_DIR=\$GOPATH/etcd_temp \n" | tee -a "$TEST_LOG" 
    printf -- "                       export ETCD_UNSUPPORTED_ARCH=s390x \n" | tee -a "$TEST_LOG" 
    printf -- " \n" | tee -a "$TEST_LOG" 
    printf -- " \n" | tee -a "$TEST_LOG" 
    printf -- "                  ##  Running system tests now. Test logs are saved in ${LOGDIR}/testLog-DATE-TIME.log  ## \n" | tee -a "$TEST_LOG" 
    printf -- "                       cd \$GOPATH/src/github.com/projectcalico/node \n" | tee -a "$TEST_LOG" 
    printf -- "                       ARCH=s390x make st 2>&1 | tee -a \$LOGDIR/\$(date +"%%F-%%T").log \n" | tee -a "$TEST_LOG" 
fi
