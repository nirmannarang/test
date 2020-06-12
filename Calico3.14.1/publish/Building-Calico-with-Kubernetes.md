# Integrating Calico with Kubernetes

Calico enables networking and network policy in Kubernetes clusters across the cloud. The instructions provided you the steps to integrate Calico with Kubernetes on Linux on IBM Z for following distribution:

* RHEL (7.6, 7.7, 7.8)
* Ubuntu (16.04, 18.04, 20.04)
* SLES (12 SP4, 12 SP5, 15 SP1)

_**General Notes:**_

* _When following the steps below please use a standard permission user unless otherwise specified._

* _A directory `/<source_root>/` will be referred to in these instructions, this is a temporary writable directory anywhere you'd like to place it._

* _Following build instructions were tested using Kubernetes version 1.15._

## 1. Build Calico basic components

Instructions for building the basic Calico components, which includes `calicoctl` and `calico/node` can be found [here](https://github.com/linux-on-ibm-z/docs/wiki/Building-Calico)

## 2. Build Kubernetes Support

### 2.1 Build `Pod2Daemon` image

* Export Environment Variable

  ```bash
  export PATCH_URL=https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/calico/3.14.1/patch
  ```

* This builds a docker image `pod2dameon` that will be used when running kubernetes with Calico

  ```bash
  git clone -b v3.14.1 https://github.com/projectcalico/pod2daemon.git $GOPATH/src/github.com/projectcalico/pod2daemon
  cd $GOPATH/src/github.com/projectcalico/pod2daemon
  ```

* Build binaries and image

  ```bash
  ARCH=s390x make GO_BUILD_VER=v0.39 image
  ```

### 2.2. Build the Calico network policy controller

* Download the source code

  ```bash
  git clone -b v3.14.1 https://github.com/projectcalico/k8s-policy.git $GOPATH/src/github.com/projectcalico/k8s-policy
  cd $GOPATH/src/github.com/projectcalico/k8s-policy
  ARCH=s390x make image
  ```

### 2.3 Tag the docker images

The built docker images need to be tagged with the version number to correctly work with kubernetes:

```bash
docker tag calico/pod2daemon-flexvol:latest-s390x calico/pod2daemon-flexvol:v3.14.1
docker tag calico/kube-controllers:latest-s390x calico/kube-controllers:v3.14.1
docker tag calico/flannel-migration-controller:latest-s390x calico/calico/flannel-migration-controller:v3.14.1
```

Verify the following images are on the system:

```txt
REPOSITORY                            TAG
quay.io/coreos/etcd                   v3.3.7-s390x
calico/pod2daemon-flexvol             latest-s390x
calico/kube-controllers               latest-s390x
calico/flannel-migration-controller   latest-s390x
calico/node                           latest-s390x
calico/cni                            latest-s390x
calico/felix                          latest-s390x
calico/typha                          latest-s390x
calico/ctl                            latest-s390x
calico/pod2daemon-flexvol             v3.14.1
calico/kube-controllers               v3.14.1
calico/flannel-migration-controller   v3.14.1
calico/node                           v3.14.1
calico/cni                            v3.14.1
calico/felix                          v3.14.1
calico/typha                          v3.14.1
calico/ctl                            v3.14.1
calico/go-build                       v0.39
```

## 3. Install Calico in Kubernetes environment

Once you have all necessary components built on Z systems, you can

* Configure and run your Kubernetes following [here](https://docs.projectcalico.org/v3.14/getting-started/kubernetes/)

  Note: If you run into problems like `Readiness probe failed: Get http://localhost:9099/readiness: dial tcp [::1]:9099: connect: connection refused` when running kubernetes, it might be because Calico requires net.ipv4.conf.all.rp_filter to be set to 0 or 1.

  Try doing

  ```shell
  sysctl -w net.ipv4.conf.all.rp_filter=1
  ```

  and retry creating the pods. See [this issue](https://github.com/projectcalico/calico/issues/2345) for more information about the error

* Install the calico policy controller following [here](https://docs.projectcalico.org/v3.14/getting-started/kubernetes/installation/calico)

## 4. Usage samples

<https://docs.projectcalico.org/security/get-started>  
