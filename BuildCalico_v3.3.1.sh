#!/bin/bash

################################################################################################################################################################
#Script Name:    BuildCalico_v3.3.1.sh 
#Description:    The script specify the commands to build Calico version v3.3.1 on Linux on IBM Z.
#Maintainer :    LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource) 
#Info/Notes :    Please refer to the instructions first for Building Calico mentioned in wiki( https://github.com/linux-on-ibm-z/docs/wiki/Building-Calico-3.x ). 
#                Build logs can be found in $GOPATH/buildLogs/
#                By Default, system tests are turned off. To run system tests for Calico, pass argument "-tests" to shell script as : ./BuildCalico_v3.3.1.sh -tests
#                Test logs can be found at $GOPATH/buildLogs/testlogN.
#                Module wise build logs can be found in PATH $GOPATH/buildLogs/
################################################################################################################################################################

set -e
set -v
export runTests=$1

if [ "$runTests" = "-tests" ]
then
	echo "System tests will also run after Calico node build is complete."
else
	echo "System tests won't run for Calico by default"
fi

### 1. Install the system dependencies
#Change the directory to your /<source_root>/ and then proceed with the script commands below.
. /etc/os-release
if [ $ID == "rhel" ]; then
	sudo yum install -y curl git wget tar gcc glibc-static.s390x make which patch
	export CC=gcc
elif [ $ID == "sles" ]; then
	sudo zypper install -y curl git wget tar gcc glibc-static.s390x make which patch
	export CC=gcc
elif [ $ID == "ubuntu" ]; then
	sudo apt-get update && sudo apt-get install -y git curl tar gcc wget make patch apt-transport-https  ca-certificates  curl software-properties-common
fi


#### 2. Install `Go` and  `etcd` as prerequisites

### 2.1 Install `Go 1.10.1`
#Change the directory to your /<source_root>/ as mentioned in Building Calico wiki, this will also be your GOPATH and WORKDIR. And then execute below commands.
export WORKDIR=$PWD
wget https://storage.googleapis.com/golang/go1.10.1.linux-s390x.tar.gz
tar xf go1.10.1.linux-s390x.tar.gz
export GOPATH=$PWD
export PATH=$PATH:$GOPATH/bin
#Create directories for module wise logs
rm -rf $GOPATH/buildLogs
mkdir -p $GOPATH/buildLogs

### 2.2 Install `etcd v3.3.7`.
cd $WORKDIR 
mkdir -p $WORKDIR/src/github.com/coreos
mkdir -p $WORKDIR/etcd_temp
cd $WORKDIR/src/github.com/coreos
git clone git://github.com/coreos/etcd
cd etcd
git checkout v3.3.7
export ETCD_DATA_DIR=$WORKDIR/etcd_temp
export ETCD_UNSUPPORTED_ARCH=s390x
./build


#### 3. Build `calicoctl` and  `calico/node` image

### Build `go-build`
##This builds a docker image calico/go-build that is used to build other components
git clone https://github.com/projectcalico/go-build $GOPATH/src/github.com/projectcalico/go-build
cd $GOPATH/src/github.com/projectcalico/go-build
git checkout v0.17

## 3.1.1 Then  build `calico/go-build-s390x` image
ARCH=s390x make build 2>&1 | tee $GOPATH/buildLogs/go-build.log
if grep -Fxq "Successfully tagged calico/go-build:latest-s390x" $GOPATH/buildLogs/go-build.log
then
    echo "Successfully built calico/go-build"
else
    echo "go-build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/go-build.log"
	exit 1
fi

docker tag calico/go-build:latest-s390x calico/go-build-s390x:latest
docker tag calico/go-build:latest-s390x calico/go-build:latest
docker tag calico/go-build:latest-s390x calico/go-build:v0.17

### 3.2 Build `calicoctl` binary and `calico/ctl` image
## 3.2.1 Download the source code
git clone https://github.com/projectcalico/calicoctl $GOPATH/src/github.com/projectcalico/calicoctl
cd $GOPATH/src/github.com/projectcalico/calicoctl
git checkout v3.3.1

## 3.2.2 Build the `calicoctl` binary and `calico/ctl` image
ARCH=s390x make calico/ctl 2>&1 | tee $GOPATH/buildLogs/calicoctl.log

if grep -Fxq "Successfully tagged calico/ctl:latest-s390x" $GOPATH/buildLogs/calicoctl.log
then
    echo "Successfully built calico/ctl"
else
    echo "calico/ctl Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/calicoctl.log"
	exit 1
fi
docker tag calico/ctl:latest-s390x calico/ctl:latest

### 3.3 Build `bird`
## 3.3.1 Download the source code
git clone https://github.com/projectcalico/bird $GOPATH/src/github.com/projectcalico/bird
cd $GOPATH/src/github.com/projectcalico/bird
git checkout v0.3.2

## 3.3.2 Create `Dockerfile-s390x`
cat << 'EOF' > Dockerfile-s390x
FROM s390x/alpine:3.8
MAINTAINER LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource)

RUN apk update
RUN apk add alpine-sdk linux-headers autoconf flex bison ncurses-dev readline-dev

WORKDIR /code
EOF

## 3.3.3 Modify `build.sh`
#Create and apply patch for build.sh for modifying the same
cat << 'EOF' > build.sh.patch
diff --git a/build.sh b/build.sh
index cca3381..b939d0d 100755
--- a/build.sh
+++ b/build.sh
@@ -14,6 +14,10 @@ if [ $ARCH = ppc64le ]; then
        ARCHTAG=-ppc64le
 fi

+if [ $ARCH = s390x ]; then
+        ARCHTAG=-s390x
+fi
+
 DIST=dist/$ARCH

 docker build -t birdbuild$ARCHTAG -f Dockerfile$ARCHTAG .
EOF

patch < build.sh.patch

## 3.3.4 Run `build.sh` to build 3 executable files (in `dist/s390x/`)
ARCH=s390x ./build.sh 2>&1 | tee $GOPATH/buildLogs/bird.log
if [[ "$(docker images -q birdbuild-s390x:latest 2> /dev/null)" == "" ]]; then
  echo "Bird build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/bird.log"
  exit 1
else
  echo "Successfully built bird module."
fi
## 3.3.5 Tag calico/bird image
docker tag birdbuild-s390x:latest calico/bird:v0.3.2-s390x
docker tag birdbuild-s390x:latest calico/bird:latest

                   
### 3.4 Build `Typha`
## 3.4.1 Download the source code
git clone https://github.com/projectcalico/typha $GOPATH/src/github.com/projectcalico/typha
cd $GOPATH/src/github.com/projectcalico/typha
git checkout v3.3.1

## 3.4.2 Modify `Makefile`
#This removes `pull` argument to stop docker from pulling x86 image forcibly
sed -i '258s/--pull//' Makefile

## 3.4.3 Modify `docker-image/Dockerfile.s390x`
cd docker-image
cat << 'EOF' > Dockerfile.s390x.patch
diff --git a/docker-image/Dockerfile.s390x b/docker-image/Dockerfile.s390x
index f3dd5da..fe8ebe1 100644
--- a/docker-image/Dockerfile.s390x
+++ b/docker-image/Dockerfile.s390x
@@ -1,7 +1,7 @@
 ARG QEMU_IMAGE=calico/go-build:latest
 FROM ${QEMU_IMAGE} as qemu

-FROM s390x/alpine:3.8
+FROM s390x/alpine:3.8 as base
 MAINTAINER LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource)

 # Enable non-native builds of this image on an amd64 hosts.
@@ -12,15 +12,19 @@ COPY --from=qemu /usr/bin/qemu-s390x-static /usr/bin/

 # Since our binary isn't designed to run as PID 1, run it via the tini init daemon.
 RUN apk add --update tini
-ENTRYPOINT ["/sbin/tini", "--"]

-ADD typha.cfg /etc/calico/typha.cfg
+FROM scratch
+COPY --from=base /sbin/tini /sbin/tini
+COPY --from=base /lib/ld-musl-s390x.so.1 /lib/libc.musl-s390x.so.1  /lib/

 # Put out binary in /code rather than directly in /usr/bin.  This allows the downstream builds
 # to more easily extract the build artefacts from the container.
-RUN mkdir /code
 ADD bin/calico-typha-s390x /code/calico-typha
+ADD typha.cfg /etc/calico/typha.cfg
+
 WORKDIR /code
+ENV PATH="$PATH:/code"

 # Run Typha by default
+ENTRYPOINT ["/sbin/tini", "--"]
 CMD ["calico-typha"]
EOF

patch < Dockerfile.s390x.patch

## 3.4.4 Build the binaries and docker image for typha
cd $GOPATH/src/github.com/projectcalico/typha
ARCH=s390x make calico/typha 2>&1 | tee $GOPATH/buildLogs/typha.log

if grep -Fxq "Successfully tagged calico/typha:latest-s390x" $GOPATH/buildLogs/typha.log
then
    echo "Successfully build calico/typha"
else
    echo "calico/typha Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/typha.log"
	exit 1
fi

### 3.5 Build `felix`
## 3.5.1 To build `felix` it  needs `felixbackend.pb.go` that is generated by a docker image `calico/protoc`. Let's first built this image.
git clone https://github.com/tigera/docker-protobuf $GOPATH/src/github.com/projectcalico/docker-protobuf
cd  $GOPATH/src/github.com/projectcalico/docker-protobuf

## 3.5.2 Modify `Dockerfile-s390x`
#Remove existing Dockerfile and create a new one to include golang generators.
rm -rf Dockerfile-s390x
cat << 'EOF' > Dockerfile-s390x
FROM s390x/golang:1.9.2

MAINTAINER LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource)

RUN apt-get update && apt-get install -y git make autoconf automake libtool unzip

# Clone the initial protobuf library down
RUN mkdir -p /src
WORKDIR /src
ENV PROTOBUF_TAG v3.5.1
RUN git clone https://github.com/google/protobuf

# Switch to protobuf folder and carry out build
WORKDIR /src/protobuf
RUN git checkout ${PROTOBUF_TAG}
# Cherry pick specific for big endian systems, see https://github.com/google/protobuf/pull/3955
RUN git cherry-pick -n 642e1ac635f2563b4a14c255374f02645ae85dac
RUN ./autogen.sh && ./configure --prefix=/usr
RUN make -j 3
RUN make check install

# Cleanup protobuf after installation
WORKDIR /src
RUN rm -rf protobuf

# TODO: Lock this down to specific versions
# Install gogo, an optimised fork of the Golang generators
RUN rm -vrf /go/src/github.com/gogo/protobuf/*
RUN go get -d github.com/gogo/protobuf/proto
WORKDIR /go/src/github.com/gogo/protobuf
RUN git checkout v1.0.0
WORKDIR /src
RUN go get github.com/gogo/protobuf/proto \
       github.com/gogo/protobuf/protoc-gen-gogo \
       github.com/gogo/protobuf/gogoproto \
       github.com/gogo/protobuf/protoc-gen-gogofast \
       github.com/gogo/protobuf/protoc-gen-gogofaster \
       github.com/gogo/protobuf/protoc-gen-gogoslick
RUN apt-get purge -y git make autoconf automake libtool unzip && apt-get clean -y

ENTRYPOINT ["protoc"]

EOF

## 3.5.3 Build and tag docker image `calico/protoc-s390x`
docker build -t calico/protoc-s390x -f Dockerfile-s390x . 2>&1 | tee $GOPATH/buildLogs/docker-protobuf.log
if grep -Fxq "Successfully tagged calico/protoc-s390x:latest" $GOPATH/buildLogs/docker-protobuf.log
then
    echo "Successfully built calico/protoc-s390x"
else
    echo "calico/protoc Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/docker-protobuf.log"
	exit 1
fi

docker tag calico/protoc-s390x:latest calico/protoc:latest-s390x


### 3.5.4 Build `felix`
git clone https://github.com/projectcalico/felix $GOPATH/src/github.com/projectcalico/felix
cd $GOPATH/src/github.com/projectcalico/felix
git checkout v3.3.1

## 3.5.5 Modify Makefile
#Change version to latest instead of v0.1
sed -i '157s/v0.1/latest/' Makefile
#Remove `pull` argument to stop docker from pulling x86 image forcibly
sed -i '351s/--pull//' Makefile

## 3.5.7 Build the felix binaries
cd $GOPATH/src/github.com/projectcalico/felix
ARCH=s390x make image 2>&1 | tee $GOPATH/buildLogs/felix.log

if grep -Fxq "Successfully tagged calico/felix:latest-s390x" $GOPATH/buildLogs/felix.log
then
    echo "Successfully built calico/felix"
else
    echo "calico/typha Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/felix.log"
	exit 1
fi


### 3.6 Build `cni-plugin` binaries and image
## 3.6.1 Download the source code
sudo mkdir -p /opt/cni/bin
git clone https://github.com/projectcalico/cni-plugin.git $GOPATH/src/github.com/projectcalico/cni-plugin
cd $GOPATH/src/github.com/projectcalico/cni-plugin
git checkout v3.3.1

## 3.6.2 Build binaries and image
ARCH=s390x make image 2>&1 | tee $GOPATH/buildLogs/cni-plugin.log

if grep -Fxq "Successfully tagged calico/cni:latest-s390x" $GOPATH/buildLogs/cni-plugin.log
then
    echo "Successfully built calico/cni-plugin"
else
    echo "calico/cni-plugin Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/cni-plugin.log"
	exit 1
fi

sudo cp bin/s390x/* /opt/cni/bin
docker tag calico/cni:latest-s390x calico/cni:latest
docker tag calico/cni:latest quay.io/calico/cni-s390x:v3.3.1


### 3.7 Build image `calico/node`
## 3.7.1 Download the source
git clone https://github.com/projectcalico/node $GOPATH/src/github.com/projectcalico/node
cd $GOPATH/src/github.com/projectcalico/node
git checkout v3.3.1

## 3.7.2 Modify `Makefile`
#Change bird tag to v0.3.2
sed -i '112s/v0.3.2-13-g17d14e60/v0.3.2/' Makefile
#Change tags from master to latest for routereflector, calicoctl etc.
sed -i '116s/master/latest/' Makefile
sed -i '117s/master/latest/' Makefile
#Change etcd image tag and version
sed -i '125s/$(ETCD_IMAGE)/quay.io\/coreos\/etcd:v3.3.7/' Makefile
#Remove `pull` argument to stop docker from pulling x86 image forcibly
sed -i '253s/--pull//' Makefile
#Delete docker pull commands to stop docker from pulling x86 image forcibly
sed -i '396d' Makefile
sed -i '404d' Makefile


## 3.7.3 Modify `Dockerfile.s390x`
sed -i '38d' Dockerfile.s390x

## 3.7.4 Get the yaml binary if not installed, needed for building `calico/node`
go get gopkg.in/mikefarah/yq.v1
cd $GOPATH/bin
ln -s yq.v1 yaml
export PATH=$PATH:$GOPATH/bin

### 3.7.5 Build `calico/node`
cd $GOPATH/src/github.com/projectcalico/node
mkdir -p filesystem/bin
mkdir -p dist
cp $GOPATH/src/github.com/projectcalico/bird/dist/s390x/* $GOPATH/src/github.com/projectcalico/node/filesystem/bin
cp $GOPATH/src/github.com/projectcalico/felix/bin/calico-felix-s390x $GOPATH/src/github.com/projectcalico/node/filesystem/bin/calico-felix
cp $GOPATH/src/github.com/projectcalico/calicoctl/bin/calicoctl-linux-s390x $GOPATH/src/github.com/projectcalico/node/dist/calicoctl
ARCH=s390x make calico/node 2>&1 | tee $GOPATH/buildLogs/node.log

if grep -Fxq "Successfully tagged calico/node:latest-s390x" $GOPATH/buildLogs/node.log
then
    echo "Successfully built calico/node"
else
    echo "calico/node Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/node.log"
	exit 1
fi

docker tag calico/node:latest-s390x quay.io/calico/node-s390x:v3.3.1
docker tag calico/node:latest-s390x calico/node

#### 4. Calico testcases


### 4.1 Build `etcd`
cd $GOPATH/src/github.com/projectcalico/
git clone https://github.com/coreos/etcd
cd etcd
git checkout v3.3.7

## 4.1.1 Modify `Dockerfile-release` for s390x
cat << 'EOF' > Dockerfile-release.patch
diff --git a/Dockerfile-release b/Dockerfile-release
index 736445f..ab0df2a 100644
--- a/Dockerfile-release
+++ b/Dockerfile-release
@@ -1,7 +1,8 @@
-FROM alpine:latest
+FROM s390x/alpine:3.8

-ADD etcd /usr/local/bin/
-ADD etcdctl /usr/local/bin/
+ADD bin/etcd /usr/local/bin/
+ADD bin/etcdctl /usr/local/bin/
+ENV ETCD_UNSUPPORTED_ARCH=s390x
 RUN mkdir -p /var/etcd/
 RUN mkdir -p /var/lib/etcd/

EOF

patch < Dockerfile-release.patch

## 4.1.2 Then build etcd and image
./build
docker build -f Dockerfile-release  -t quay.io/coreos/etcd . 2>&1 | tee $GOPATH/buildLogs/etcd.log

if grep -Fxq "Successfully tagged quay.io/coreos/etcd:latest" $GOPATH/buildLogs/etcd.log
then
    echo "Successfully built etcd image"
else
    echo "etcd image Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/etcd.log"
	exit 1
fi

cd bin
tar cvf etcd-v3.3.7-linux-s390x.tar etcd etcdctl
gzip etcd-v3.3.7-linux-s390x.tar
docker tag quay.io/coreos/etcd:latest quay.io/coreos/etcd:v3.3.7-s390x


# ### 4.2 Build `Confd` Image
# git clone https://github.com/projectcalico/confd $GOPATH/src/github.com/projectcalico/confd-v3.1.3
# cd $GOPATH/src/github.com/projectcalico/confd-v3.1.3
# git checkout v3.1.3

# ## 4.2.1 Create `Dockerfile-s390x`
# cat << 'EOF' > Dockerfile-s390x
# FROM s390x/alpine:3.6
# MAINTAINER LoZ Open Source Ecosystem (https://www.ibm.com/developerworks/community/groups/community/lozopensource)

# # Copy in the binary.
# ADD bin/confd /bin/confd
# EOF

# ## 4.2.2 Build confd image
# cd $GOPATH/src/github.com/projectcalico/confd-v3.1.3
# ARCH=s390x make container 2>&1 | tee $GOPATH/buildLogs/confd.log

# if grep -Fxq "Successfully tagged calico/confd-s390x:latest" $GOPATH/buildLogs/confd.log
# then
    # echo "Successfully built calico/confd"
# else
    # echo "calico/confd Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/confd.log"
	# exit 1
# fi

# docker tag calico/confd-s390x:latest calico/confd:v3.1.1-s390x


# ### 4.3 Build `calico/routereflector`
# git clone https://github.com/projectcalico/routereflector.git $GOPATH/src/github.com/projectcalico/routereflector
# cd $GOPATH/src/github.com/projectcalico/routereflector
# git checkout v0.6.3
# cp $GOPATH/src/github.com/projectcalico/bird/dist/s390x/* image/

# ## 4.3.1 Modify `Makefile`
# sed -i '38s/v0.16/v0.17/' Makefile
# sed -i '103d' Makefile

# ## 4.3.2 Build the routereflector 
# cd $GOPATH/src/github.com/projectcalico/routereflector
# ARCH=s390x make image 2>&1 | tee $GOPATH/buildLogs/routereflector.log

# if grep -Fxq "Successfully tagged calico/routereflector:latest-s390x" $GOPATH/buildLogs/routereflector.log
# then
    # echo "Successfully built calico/routereflector"
# else
    # echo "calico/routereflector Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/routereflector.log"
	# exit 1
# fi

# docker tag calico/routereflector:latest-s390x calico/routereflector:latest


### 4.4 Build `calico/dind`
git clone https://github.com/projectcalico/dind $GOPATH/src/github.com/projectcalico/dind
cd $GOPATH/src/github.com/projectcalico/dind
## 4.4.1 Build the dind
docker build -t calico/dind -f Dockerfile-s390x . 2>&1 | tee $GOPATH/buildLogs/dind.log

if grep -Fxq "Successfully tagged calico/dind:latest" $GOPATH/buildLogs/dind.log
then
    echo "Successfully built calico/dind"
else
    echo "calico/dind Build FAILED, Stopping further build !!! Check logs at $GOPATH/buildLogs/dind.log"
	exit 1
fi


###4.5 Build `calico/test`
cd $GOPATH/src/github.com/projectcalico/node/calico_test/
mkdir pkg
cp $GOPATH/src/github.com/projectcalico/etcd/bin/etcd-v3.3.7-linux-s390x.tar.gz pkg

## 4.5.1 Modify `Dockerfile.s390x.calico_test`
sed -i '62s/v3.3.1/v3.3.7/' Dockerfile.s390x.calico_test


### 4.6 Run the test cases
#Pull s390x images for creating workload
docker pull s390x/busybox
docker tag s390x/busybox busybox
docker pull s390x/nginx
docker tag s390x/nginx nginx
docker tag quay.io/coreos/etcd quay.io/coreos/etcd:v3.3.7

## 4.6.1 Create `Dockerfile.s390x`
cd $GOPATH/src/github.com/projectcalico/node/workload
sed -i '6s/3.6/3.8/' Dockerfile.s390x

##########################################################################################################################################################
##########################################################################################################################################################
#														 CALICO NODE & TESTS BUILD COMPLETED SUCCESSFULLY 												 #
##########################################################################################################################################################
##########################################################################################################################################################

#Verify all images are built/tagged
cd $GOPATH
cat << 'EOF' > docker_images_expected.txt
calico/dind:latest
quay.io/coreos/etcd:latest
quay.io/coreos/etcd:v3.3.7
quay.io/coreos/etcd:v3.3.7-s390x
calico/node:latest
calico/node:latest-s390x
quay.io/calico/node-s390x:v3.3.1
quay.io/calico/cni-s390x:v3.3.1
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

docker images --format "{{.Repository}}:{{.Tag}}" > docker_images.txt

count=0
while read image; do
  if ! grep -q $image docker_images.txt; then
  echo "$image"
  count=`expr $count + 1`
  fi
done < docker_images_expected.txt
if [ "$count" != "0" ]; then
	echo "Above $count images need to be present. Check the logs of above images/modules in $GOPATH/buildLogs/"
	exit 1
fi


## 4.6.2 Execute test cases(Optional)
#Will only run if arg "-tests" is passed to shell script
if [ "$runTests" = "-tests" ]
then
	echo "Running system tests now. Testlogs are saved in $GOPATH/buildLogs/testlogN"
	cd $GOPATH/src/github.com/projectcalico/node
	ARCH=s390x make st 2>&1 | tee $GOPATH/buildLogs/testlog1
else
	echo "System tests won't run for Calico by default."
fi

