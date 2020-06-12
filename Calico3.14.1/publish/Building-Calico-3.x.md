# Building Calico

The instructions specify the steps to build `Calico` version [v3.14.1](https://docs.projectcalico.org/v3.14/release-notes/) on Linux on IBM Z  for following distributions:

* RHEL (7.6, 7.7, 7.8)
* SLES (12 SP4, 12 SP5, 15 SP1)
* Ubuntu (16.04, 18.04, 20.04)

_**General Notes:**_

* _When following the steps below please use a standard permission user unless otherwise specified._
* _A directory `/<source_root>/` will be referred to in these instructions, this is a temporary writable directory anywhere you'd like to place it._
* _`<host_run_etcd_ip>` and `<host-ip>` will be referred to the IP address of the host where etcd service is run._
* _Please note that in case if any calico module build gets failed, make sure to run `make clean` before rerunning the build command._
* _While running build or tests, errors like `Error: No such container: calico-etcd-ssl   Makefile:369: recipe for target 'stop-etcd' failed   make[1]: [stop-etcd] Error 1 (ignored)` might be seen and can be simply ignored. These are some extra checks for checking previously running containers and tries to stop and remove them in case they are already running._
* _Docker-ce versions between 17.06 and 18.02 have a known [issue](https://github.com/docker/for-linux/issues/238) on IBM Z. This has been fixed in version 18.03, refer to docker release [link](https://github.com/docker/docker-ce/releases) for most up to date information on which another version might contain this fix._
* You may need to manage docker as a non-root user in order to build Calico. See [here](https://docs.docker.com/install/linux/linux-postinstall/) for instructions if needed.
* Export Environment Variable

  ```bash
  export PATCH_URL=https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Calico/3.14.1/patch
  ```

## 1. Build using script

If you want to build Calico using manual steps, go to STEP 2.

Use the following commands to build Calico using the build [script](https://github.com/linux-on-ibm-z/scripts/tree/master/Calico). Please make sure you have wget and Docker installed.

```bash
wget https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Calico/3.14.1/build_calico.sh

# Build Calico
bash build_calico.sh   [Provide -t option for executing build with tests]
```

If the build and tests complete successfully, go to STEP 6. In case of error, check logs at `$HOME/Calico_v3.14.1/logs/` for more details or go to STEP 2 to follow manual build steps.

In case build is successful but tests fail, run the following command to set Calico environment and go to STEP 4.8

```bash
source $HOME/setenv.sh    #Source environment file
```

## 2. Install the system dependencies

* RHEL (7.6, 7.7, 7.8)

  ```bash
  sudo yum install -y curl git wget tar gcc glibc-static.s390x make which patch
  ```

* SLES (12 SP4, 12 SP5, 15 SP1)

  ```bash
  sudo zypper install -y curl git wget tar gcc glibc-devel-static make which patch
  ```

* Ubuntu (16.04, 18.04, 20.04)

  ```bash
  sudo apt-get update
  sudo apt-get install -y patch git curl tar gcc wget make
  ```

* Docker packages are provided for SLES, Ubuntu and RHEL (7.6 or higher) in their respective repositories. Instructions for installing Docker on RHEL (7.3) can be found [here](http://www.ibm.com/developerworks/linux/linux390/docker.html). You may use the same instructions for RHEL (7.6, 7.7, 7.8) as the binaries are expected to be compatible. More information about Docker CE can be found [here](https://docs.docker.com/install/).

## 3. Install prerequisites

### 3.1 Install Go 1.14.2

Instructions for building Go can be found [here](https://github.com/linux-on-ibm-z/docs/wiki/Building-Go)
  
### 3.2 Install etcd v3.3.7

Set environment variables

```bash
cd $SOURCE_ROOT
export GOPATH=$SOURCE_ROOT
export PATH=$GOPATH/bin:$PATH
export ETCD_UNSUPPORTED_ARCH=s390x
```

Clone the `coreos/etcd` github repository:

```bash
mkdir -p $SOURCE_ROOT/src/github.com/coreos
cd $SOURCE_ROOT/src/github.com/coreos
git clone -b v3.3.7 git://github.com/coreos/etcd
cd etcd
```

Download `Dockerfile-release.s390x`:

```bash
curl -o "Dockerfile-release.s390x" $PATCH_URL/Dockerfile-release.s390x
```

Build etcd binaries and image using following commands:

```bash
./build
BINARYDIR=./bin TAG=quay.io/coreos/etcd ./scripts/build-docker v3.3.7
```

Create tarball for calico testing.

```bash
tar -zcvf etcd-v3.3.7-linux-s390x.tar.gz -C bin etcd etcdctl
```

## 4. Build calicoctl and calico/node image

### 4.1 Build bpftool image

* This builds a docker image `calico/bpftool:v5.3-s390x`. Certain components require the binary provided in this image.

  Clone the `projectcalico/bpftool` github repository:

  ```bash
  git clone https://github.com/projectcalico/bpftool $GOPATH/src/github.com/projectcalico/bpftool
  cd $GOPATH/src/github.com/projectcalico/bpftool
  ```

  Download the `Dockerfile.s390x`.

  ```bash
  curl -o "Dockerfile.s390x" $PATCH_URL/Dockerfile.s390x.bpftool
  ```

  Then build the `calico/bpftool:v5.3-s390x` image:

  ```bash
  ARCH=s390x make image
  ```

### 4.2 Build go-build

* This builds a docker image `calico/go-build:v0.39` that is used to build other components

  Clone the `projectcalico/go-build` github repository.

  ```bash
  git clone -b v0.39 https://github.com/projectcalico/go-build $GOPATH/src/github.com/projectcalico/go-build
  cd $GOPATH/src/github.com/projectcalico/go-build
  ```

  Download the modified `Dockerfile.s390x` and patch the `Makefile`.

  ```bash
  curl -o "Dockerfile.s390x" $PATCH_URL/Dockerfile.s390x.v0.39
  curl -s $PATCH_URL/Makefile.diff.v0.39 | git apply -
  ```

  Then build `calico/go-build:v0.39` image:

  ```bash
  ARCH=s390x VERSION=v0.39 ARCHIMAGE='$(DEFAULTIMAGE)' make image
  ```

### 4.3 Build calicoctl

* Clone the `projectcalico/calicoctl` github repository.
  
  ```bash
  git clone -b v3.14.1 https://github.com/projectcalico/calicoctl $GOPATH/src/github.com/projectcalico/calicoctl
  cd $GOPATH/src/github.com/projectcalico/calicoctl
  ```

* Build the binaries and docker image for `calicoctl`
  
  ```bash
  ARCH=s390x make image
  ```

### 4.4 Build Typha

* Clone the `projectcalico/typha` github repository.
  
  ```bash
  git clone -b v3.14.1 https://github.com/projectcalico/typha $GOPATH/src/github.com/projectcalico/typha
  cd $GOPATH/src/github.com/projectcalico/typha
  ```

* Patch `Makefile`
  
  ```bash
  curl -s $PATCH_URL/Makefile.diff.typha | git apply -
  ```

* Build the binaries and docker image for `typha`
  
  ```bash
  ARCH=s390x make GO_BUILD_VER=v0.39 image
  ```

#### 4.5 Build Felix

* Clone the `projectcalico/felix` github repository.
  
  ```bash
  git clone -b v3.14.1 https://github.com/projectcalico/felix.git $GOPATH/src/github.com/projectcalico/felix
  cd $GOPATH/src/github.com/projectcalico/felix
  ```

* Download modified `docker-image/Dockerfile.s390x`, patch `Makefile` and patch `bpf-gpl/Makefile`
  
  ```bash
  curl -o "docker-image/Dockerfile.s390x" $PATCH_URL/Dockerfile.s390x.felix
  curl -s $PATCH_URL/Makefile.diff.felix | git apply -
  curl -s $PATCH_URL/Makefile.diff.bpf-gpl | git apply -
  ```

* Build the binaries and docker image for `felix`
  
  ```bash
  ARCH=s390x make GO_BUILD_VER=v0.39 image
  ```

### 4.6 Build cni-plugin

* Clone the `projectcalico/cni-plugin` github repository.
  
  ```bash
  git clone -b v3.14.1 https://github.com/projectcalico/cni-plugin.git $GOPATH/src/github.com/projectcalico/cni-plugin
  cd $GOPATH/src/github.com/projectcalico/cni-plugin
  ```

* Build the binaries and docker image for `cni`
  
  ```bash
  ARCH=s390x make GO_BUILD_VER=v0.39 image
  ```

### 4.7 Build Node

* Clone the `projectcalico/node` github repository.
  
  ```bash
  git clone -b v3.14.1 https://github.com/projectcalico/node.git $GOPATH/src/github.com/projectcalico/node
  cd $GOPATH/src/github.com/projectcalico/node
  ```

* Modify `go.mod` to point to local felix repository.
  
  ```bash
  go mod edit -replace=github.com/projectcalico/felix=../felix
  ```

* Download modified `Dockerfile.s390x` and patch `Makefile`
  
  ```bash
  curl -o "Dockerfile.s390x" $PATCH_URL/Dockerfile.s390x.node
  curl -s $PATCH_URL/Makefile.diff.node | git apply -
  ```

* Build `node`
  * Creating filesystem/bin and dist directories for keeping binaries

     ```bash
     cd $GOPATH/src/github.com/projectcalico/node
     mkdir -p filesystem/bin
     mkdir -p dist
     cp ../felix/bin/calico-felix-s390x ./filesystem/bin/calico-felix
     cp ../calicoctl/bin/calicoctl-linux-s390x ./dist/calicoctl
     ```

  * Build the binaries and docker image for `node`

    ```bash
    ARCH=s390x EXTRA_DOCKER_ARGS="-v `pwd`/../felix:/go/src/github.com/projectcalico/felix" make image
    ```

### 4.8 Apply docker tags

Apply docker tags to label images with the version.

```bash
docker tag calico/node:latest-s390x calico/node:v3.14.1
docker tag calico/felix:latest-s390x calico/felix:v3.14.1
docker tag calico/typha:latest-s390x calico/typha:v3.14.1
docker tag calico/ctl:latest-s390x calico/ctl:v3.14.1
docker tag calico/cni:latest-s390x calico/cni:v3.14.1
```

Verify that following docker images with respective tags are created:
  
```txt
REPOSITORY                  TAG
quay.io/coreos/etcd         v3.3.7-s390x
calico/node                 latest-s390x
calico/cni                  latest-s390x
calico/felix                latest-s390x
calico/typha                latest-s390x
calico/ctl                  latest-s390x
calico/node                 v3.14.1
calico/cni                  v3.14.1
calico/felix                v3.14.1
calico/typha                v3.14.1
calico/ctl                  v3.14.1
calico/go-build             v0.39
```

### 4.9 Test node

* First start `etcd` in background that is required for running `calico/node`

  ```bash
  cd $GOPATH/src/github.com/coreos/etcd
  ./bin/etcd --listen-client-urls=http://<host-ip>:2379 --advertise-client-urls=http://<host-ip>:2379 &
  ```

* Start `calico/node`

  ```bash
  cd $GOPATH/src/github.com/projectcalico/node
  sudo ETCD_ENDPOINTS=http://<host_run_etcd_ip>:2379 dist/calicoctl node run --node-image=calico/node:latest-s390x
  ```

Check the output and confirm that `calico/node` is  successfully started.

## 5. Calico testcases (Optional)

### 5.1 Build calico/dind

* Clone the `projectcalico/dind` github repository

  ```bash
  git clone https://github.com/projectcalico/dind $GOPATH/src/github.com/projectcalico/dind
  cd $GOPATH/src/github.com/projectcalico/dind
  ```

* Build the dind

  ```bash
  docker build -t calico/dind -f Dockerfile-s390x .
  ```
  
### 5.2 Modify Dockerfile for calico/test

* Copy over `etcd-v3.3.7-linux-s390x.tar.gz`

  ```bash
  cd $GOPATH/src/github.com/projectcalico/node
  mkdir -p calico_test/pkg
  cp $GOPATH/src/github.com/coreos/etcd/etcd-v3.3.7-linux-s390x.tar.gz calico_test/pkg
  ```

* Modify `Dockerfile.s390x.calico_test`

  ```bash
  cd $GOPATH/src/github.com/projectcalico/node
  curl -s $PATCH_URL/Dockerfile.s390x.calico_test.diff | git apply -
  ```

* Modify `Dockerfile.s390x` for workload

  ```bash
  cd $GOPATH/src/github.com/projectcalico/node
  curl -s $PATCH_URL/Dockerfile.s390x.workload.diff | git apply -
  ```

### 5.3 Execute Calico Tests

_**Note:**_ While running below command for running tests, make sure `etcd` and `calico-node` are not running already. Kill `etcd` process and Stop `calico-node` container using following commands:

  ```bash
  sudo pkill etcd
  docker rm -f calico-node
  ```

  Execute test cases

  ```bash
  cd $GOPATH/src/github.com/projectcalico/node
  ARCH=s390x CALICOCTL_VER=latest-s390x CNI_VER=latest-s390x EXTRA_DOCKER_ARGS="-v `pwd`/../felix:/go/src/github.com/projectcalico/felix" make st
  ```
  
### 5.4 Verify test results

Expected output for successful test case results:

```log
XML: /code/report/nosetests.xml
[success] 4.95% tests.st.ipam.test_ipam.MultiHostIpam.test_pool_wrap_1: 137.6140s
[success] 4.85% tests.st.ipam.test_ipam.MultiHostIpam.test_pool_wrap_0: 134.9024s
[success] 3.55% tests.st.policy.test_profile.MultiHostMainline.test_rules_source_ip_sets: 98.5571s
.
.
.
[success] 0.02% tests.st.calicoctl.test_default_pools.TestDefaultPools.test_default_pools_0: 0.6688s
[success] 0.02% tests.st.bgp.test_global_config.TestBGP.test_defaults: 0.5905s
[success] 0.01% tests.st.calicoctl.test_node_run.TestNodeRun.test_node_run_dryrun: 0.2424s
[success] 0.01% tests.st.calicoctl.test_node_status.TestNodeStatus.test_node_status_fails: 0.2364s
----------------------------------------------------------------------
Ran 104 tests in 2908.902s

OK (SKIP=9)
make stop-etcd
"Build dependency versions"
BIRD_VERSION          = v0.3.3-151-g767b5389
"Test dependency versions"
CNI_VER               = latest
"Calico git version"
GIT_VERSION           = v3.14.1-dirty
make[1]: Entering directory `$HOME/go/src/github.com/projectcalico/node'
calico-etcd
make[1]: Leaving directory `$HOME/go/src/github.com/projectcalico/node'
```

_**Note:**_

* Certain tests fail for RHEL (7.6, 7.7, 7.8), this might be due to `firewalld` service being active. Stop the firewall, restart docker and then rerun the tests.
* Node there is a single failure `tests.st.bgp.test_ipip.TestIPIP.test_issue_1584_0_bird` for both s390x and intel with Ubuntu 20.04.
* There are intermittent test failures. To resolve them run them individually.
  * To run a subset of failed tests, you can refer to [here](https://github.com/projectcalico/node#how-can-i-run-a-subset-of-the-tests) for more information

## 6. Calico Integration

### 6.1 [Calico with Kubernetes](https://github.com/linux-on-ibm-z/docs/wiki/Building-Calico-with-Kubernetes)

### References

<https://github.com/projectcalico>  
