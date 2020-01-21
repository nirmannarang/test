# Building Apache Mesos

The instructions provided below specify the steps to build [Apache Mesos](http://mesos.apache.org/) version 1.8.1 on Linux on IBM Z for the following distributions:
*   RHEL (7.5, 7.6, 7.7)
*   SLES (12 SP4, 15, 15 SP1)
*   Ubuntu (16.04, 18.04, 19.04)

_**General Notes:**_
*   _When following the steps below please use a standard permission user unless otherwise specified_
*   _A directory `/<source_root>/` will be referred to in these instructions, this is a temporary writable directory anywhere you'd like to place it_

## Step 1: Building and Installing Apache Mesos

#### 1.1) Build using script

If you want to build mesos using manual steps, go to STEP 1.2.

Use the following commands to build mesos using the build [script](https://github.com/linux-on-ibm-z/scripts/tree/master/ApacheMesos). Please make sure you have wget installed.

```
wget -q https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/ApacheMesos/1.8.1/build_mesos.sh

# Build mesos
bash build_mesos.sh   [Provide -o option for executing build using OpenJDK]   
```

If the build completes successfully, go to STEP 3. In case of error, check `logs` for more details or go to STEP 1.2 to follow manual build steps.

#### 1.2) Install dependencies
```
export SOURCE_ROOT=/<source_root>/
```

*   RHEL (7.5, 7.6, 7.7)

    *   With IBM SDK
        ```bash
        sudo yum install -y apr-devel autoconf bzip2 curl cyrus-sasl-devel cyrus-sasl-md5 gcc gcc-c++ git java-1.8.0-ibm-devel libcurl-devel libtool make maven openssl-devel patch python-devel python-six subversion-devel tar wget zlib-devel
        ```

    *   With OpenJDK
        ```bash
        sudo yum install -y apr-devel autoconf bzip2 curl cyrus-sasl-devel cyrus-sasl-md5 gcc gcc-c++ git java-1.8.0-openjdk-devel libcurl-devel libtool make maven openssl-devel patch python-devel python-six subversion-devel tar wget zlib-devel
        ```

*   SLES (12 SP4, 15, 15 SP1)

    *   With IBM SDK
        ```bash
        sudo zypper install --auto-agree-with-licenses -y autoconf bzip2 curl cyrus-sasl-crammd5 cyrus-sasl-devel gcc gcc-c++ git java-1_8_0-ibm-devel libapr1-devel libcurl-devel libopenssl-devel libtool make patch python-devel python-pip python-six subversion-devel tar wget zlib-devel gawk gzip
        ```

    *   With OpenJDK
        ```bash
        sudo zypper install -y autoconf bzip2 curl cyrus-sasl-crammd5 cyrus-sasl-devel gcc gcc-c++ git java-1_8_0-openjdk-devel libapr1-devel libcurl-devel libopenssl-devel libtool make patch python-devel python-pip python-six subversion-devel tar wget zlib-devel gawk gzip
        ```

*   Ubuntu (16.04, 18.04, 19.04)

    *   With IBM SDK
        ```bash
        sudo apt-get update
        sudo apt-get install -y autoconf bzip2 curl gcc g++ git libapr1-dev libcurl4-nss-dev libsasl2-dev libssl-dev libsvn-dev libtool make maven patch python-dev python-six tar wget zlib1g-dev
        ```
        Download [IBM Java 8](https://developer.ibm.com/javasdk/downloads/sdk8/) SDK and follow the instructions as per given in the link. Update `JAVA_HOME` and `PATH` accordingly.

    *   With OpenJDK
        ```bash
        sudo apt-get update
        sudo apt-get install -y autoconf bzip2 curl gcc g++ git libapr1-dev libcurl4-nss-dev libsasl2-dev libssl-dev libsvn-dev libtool make maven openjdk-8-jdk patch python-dev python-six tar wget zlib1g-dev
        ```

*   Install Maven 3.3.9 **(For SLES only)**
    ```bash
    cd $SOURCE_ROOT
    wget https://archive.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
    sudo tar zxf apache-maven-3.3.9-bin.tar.gz -C /opt/
    export M2_HOME=/opt/apache-maven-3.3.9
    export PATH=$M2_HOME/bin:$PATH
    ```

*  Install curl 7.64 **(For Ubuntu 18.04 only)**
    ```bash
    cd $SOURCE_ROOT
    wget https://curl.haxx.se/download/curl-7.64.0.tar.gz
    tar -xzvf curl-7.64.0.tar.gz
    cd curl-7.64.0
    ./configure --disable-shared
    make
    sudo make install
    sudo ldconfig
    ```   

*   Set environment variables only for OpenJDK:
    ```bash
    export JAVA_HOME=/usr/lib/jvm/java-1.8.0					# Only for RHEL
    export JAVA_HOME=/usr/lib64/jvm/java-1.8.0					# Only for SLES
    export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-s390x				# Only for Ubuntu
    export JAVA_TOOL_OPTIONS='-Xmx2048M'
    export PATH=$JAVA_HOME/bin:$PATH
    ```

*   Set environment variables only for IBM SDK:
	```bash
	export JAVA_HOME=/usr/lib/jvm/java-1.8.0-ibm					# Only for RHEL
    export JAVA_HOME=/usr/lib64/jvm/java-1.8.0-ibm					# Only for SLES
    export JVM_DIR=$JAVA_HOME/jre/lib/s390x/default
    export JAVA_TEST_LDFLAGS="-L$JVM_DIR -R$JVM_DIR -Wl,-ljvm -ldl"
    export JAVA_JVM_LIBRARY=$JAVA_HOME/jre/lib/s390x/default/libjvm.so
    export PATH=$JAVA_HOME/bin:$PATH
    ```  

#### 1.3) Download source code and apply patch as given below

```bash
cd $SOURCE_ROOT
git clone https://github.com/apache/mesos.git
cd mesos
git checkout 1.8.1
```

Bundling gRPC 1.11.0
```bash
cd $SOURCE_ROOT/mesos/3rdparty/
git clone -b v1.11.0 https://github.com/grpc/grpc.git grpc-1.11.0
cd grpc-1.11.0/
git submodule update --init third_party/cares
cd ..
tar zcf grpc-1.11.0.tar.gz --exclude .git grpc-1.11.0
rm -rf grpc-1.11.0
```

Modify `$SOURCE_ROOT/mesos/3rdparty/versions.am`:
```diff
@@ -27,7 +27,7 @@ ELFIO_VERSION = 3.2
 GLOG_VERSION = 0.3.3
 GOOGLETEST_VERSION = 1.8.0
 GPERFTOOLS_VERSION = 2.5
-GRPC_VERSION = 1.10.0
+GRPC_VERSION = 1.11.0
 HTTP_PARSER_VERSION = 2.6.2
 JEMALLOC_VERSION = 5.0.1
 LEVELDB_VERSION = 1.19
```

Modify `$SOURCE_ROOT/mesos/src/python/native_common/ext_modules.py.in`:
```diff
@@ -151,7 +151,7 @@ def _create_module(module_name):


     # We link different grpc library variants based on whether SSL is enabled.
-    grpc = os.path.join('3rdparty', 'grpc-1.10.0')
+    grpc = os.path.join('3rdparty', 'grpc-1.11.0')
     grpc_variant = '_unsecure' if '@ENABLE_SSL_TRUE@' == '#' else ''
     libgrpcpp = os.path.join(abs_top_builddir, grpc, 'libs', 'opt', 'libgrpc++%s.a' % grpc_variant)
     libgrpc = os.path.join(abs_top_builddir, grpc, 'libs', 'opt', 'libgrpc%s.a' % grpc_variant)
```

Append the following lines to file `$SOURCE_ROOT/mesos/3rdparty/protobuf-3.5.0.patch`:
```diff
diff --git a/src/google/protobuf/stubs/atomicops_internals_generic_gcc.h b/src/google/protobuf/stubs/atomicops_internals_generic_gcc.h
index 0b0b06c..075c406 100644
--- a/src/google/protobuf/stubs/atomicops_internals_generic_gcc.h
+++ b/src/google/protobuf/stubs/atomicops_internals_generic_gcc.h
@@ -146,6 +146,14 @@ inline Atomic64 NoBarrier_Load(volatile const Atomic64* ptr) {
   return __atomic_load_n(ptr, __ATOMIC_RELAXED);
 }

+inline Atomic64 Release_CompareAndSwap(volatile Atomic64* ptr,
+                                       Atomic64 old_value,
+                                       Atomic64 new_value) {
+  __atomic_compare_exchange_n(ptr, &old_value, new_value, false,
+                              __ATOMIC_RELEASE, __ATOMIC_ACQUIRE);
+  return old_value;
+}
+
 #endif // defined(__LP64__)

 }  // namespace internal
```

**(For Ubuntu 19.04 only)**  Append the following lines to file `$SOURCE_ROOT/mesos/3rdparty/boost-1.65.0.patch`: (see https://github.com/boostorg/mpl/pull/34)
```diff
diff --git a/boost/mpl/assert.hpp b/boost/mpl/assert.hpp
index 1af1b05..e41b583 100644
--- a/boost/mpl/assert.hpp
+++ b/boost/mpl/assert.hpp
@@ -184,16 +184,27 @@
     typedef typename assert_arg_pred_impl<p>::type type;
 };
 
+#if defined(BOOST_GCC) && BOOST_GCC >= 80000
+#define BOOST_MPL_IGNORE_PARENTHESES_WARNING
+#pragma GCC diagnostic push
+#pragma GCC diagnostic ignored "-Wparentheses"
+#endif
+
 template< typename Pred >
-failed ************ (Pred::************ 
+failed ************ (Pred::************
       assert_arg( void (*)(Pred), typename assert_arg_pred<Pred>::type )
     );
 
 template< typename Pred >
-failed ************ (boost::mpl::not_<Pred>::************ 
+failed ************ (boost::mpl::not_<Pred>::************
       assert_not_arg( void (*)(Pred), typename assert_arg_pred_not<Pred>::type )
     );
 
+#ifdef BOOST_MPL_IGNORE_PARENTHESES_WARNING
+#undef BOOST_MPL_IGNORE_PARENTHESES_WARNING
+#pragma GCC diagnostic pop
+#endif
+
 template< typename Pred >
 AUX778076_ASSERT_ARG(assert<false>)
 assert_arg( void (*)(Pred), typename assert_arg_pred_not<Pred>::type );
```

#### 1.4) Build and Install Apache Mesos

```bash
cd $SOURCE_ROOT/mesos
./bootstrap
mkdir build
cd build
../configure
make
sudo make install
```

## Step 2: Testing (Optional)

_**NOTE:** Test cases need to be executed as root user._

#### Prerequisites for running the Apache Mesos test suite:
*   Python 3  
    *   Python 3 for RHEL, SLES and Ubuntu can be found in their respective repositories.
*   Docker  
    *   Docker for SLES and Ubuntu can be found in their respective repositories. Instructions for installing Docker on RHEL can be found [here](http://www.ibm.com/developerworks/linux/linux390/docker.html).

#### 2.1)  Steps to prepare images required for Apache Mesos test cases

Test cases of Apache Mesos uses the following images: `alpine`, `chhsiao/overwrite`, `mesosphere/alpine-expect`, `mesosphere/inky`, `mesosphere/test-executor`, `tnachen/test-executor`, `haosdent/https-server`, `zhq527725/https-server` and `zhq527725/whiteout`. Dockerfiles for each of these images is given below. Make sure all the images are present on your machine before you start testing.

Use `docker build` command to create all of the Docker images below:
```bash
docker build -t <image_name> .
```

*   Dockerfile for image **mesosphere/alpine-expect**:
    ```Dockerfile
    FROM s390x/alpine
    RUN apk add --update expect
    ```

*   Dockerfile for image **mesosphere/inky**:
    ```Dockerfile
    FROM s390x/busybox
    CMD ["inky"]
    ENTRYPOINT ["echo"]
    ```

*   Dockerfile for both the images **mesosphere/test-executor** and **tnachen/test-executor**:
    ```Dockerfile
    FROM s390x/golang:1.7.5 as executor_builder
    RUN mkdir -p src/github.com/mesos/ \
        && cd src/github.com/mesos/ \
        && git clone https://github.com/tnachen/go-mesos.git mesos-go \
        && cd mesos-go/examples/ \
        && sed -i 's/-race//g' Makefile \
        && go get github.com/tools/godep \
        && godep restore \
        && make

    FROM s390x/busybox
    COPY --from=executor_builder /go/src/github.com/mesos/mesos-go/examples/_output/executor /bin/test-executor
    ```

*   Dockerfile for image **zhq527725/whiteout**:
    ```Dockerfile
    FROM s390x/alpine
    RUN mkdir -p /dir1/dir2 && touch /dir1/file1 && touch /dir1/dir2/file2
    RUN rm -rf /dir1/file1 && rm -rf /dir1/dir2 && mkdir /dir1/dir2 && touch /dir1/dir2/file3
    ```

*   Dockerfile for image **chhsiao/overwrite**:
    ```Dockerfile
    FROM s390x/alpine
    RUN mkdir /merged /replaced1 /replaced2 && touch /merged/m1 /replaced1/r1 /replaced2/r2 /replaced3 baz && ln -s /merged /replaced4 && ln -s baz foo && ln -s bar bar && ln -s ../../../../../../../abc xyz
    RUN rm -rf /replaced1 /replaced2 /replaced3 /replaced4 foo bar baz xyz && mkdir /replaced3 /replaced4 && touch /merged/m2 /replaced1 bar xyz && ln -s /merged /replaced2 && ln -s bar foo && ln -s baz baz
    ```

*   Steps for building both **haosdent/https-server** and **zhq527725/https-server** docker images:

    *   For **haosdent/https-server**, download files as given below
        ```bash
        git clone https://github.com/haosdent/https-server
        cd https-server
        docker build -t haosdent/https-server .
        ```

    *   For **zhq527725/https-server**, download files as given below
        ```bash
        git clone https://github.com/qianzhangxa/https-server.git
        cd https-server
        docker build -t zhq527725/https-server .
        ```

Steps to save docker images to `/opt/docker/images`:
```bash
mkdir -p /opt/docker/images
cd /opt/docker/images
docker pull alpine
docker save alpine >> alpine.tar
docker pull hello-world
docker save hello-world >> hello-world.tar
mkdir mesosphere
docker save mesosphere/alpine-expect >> mesosphere/alpine-expect.tar
docker save mesosphere/inky >> mesosphere/inky.tar
mkdir haosdent
docker save haosdent/https-server >> haosdent/https-server.tar
mkdir zhq527725
docker save zhq527725/https-server >> zhq527725/https-server.tar
docker save zhq527725/whiteout >> zhq527725/whiteout.tar
mkdir chhsiao
docker save chhsiao/overwrite >> chhsiao/overwrite.tar
```

#### 2.2) Modify the following files as given below

*   Modify `$SOURCE_ROOT/mesos/src/slave/flags.cpp`:
    ```diff
    @@ -211,7 +211,7 @@ mesos::internal::slave::Flags::Flags()
           "path (e.g., `/tmp/docker/images`), or as an HDFS URI (*experimental*)\n"
           "(e.g., `hdfs://localhost:8020/archives/`). Note that this option won't\n"
           "change the default registry server for Docker containerizer.",
    -      "https://registry-1.docker.io");
    +      "/opt/docker/images");

       add(&Flags::docker_store_dir,
           "docker_store_dir",
    ```

*   Modify `$SOURCE_ROOT/mesos/src/tests/containerizer/provisioner_docker_tests.cpp`:
    ```diff
    @@ -643,13 +643,13 @@ INSTANTIATE_TEST_CASE_P(
         ProvisionerDockerTest,
         ::testing::ValuesIn(vector<string>({
             "alpine", // Verifies the normalization of the Docker repository name.
    -        "library/alpine",
    -        "gcr.io/google-containers/busybox:1.24", // manifest.v1+prettyjws
    -        "gcr.io/google-containers/busybox:1.27", // manifest.v2+json
    +        // "library/alpine",
    +        // "gcr.io/google-containers/busybox:1.24", // manifest.v1+prettyjws
    +        // "gcr.io/google-containers/busybox:1.27", // manifest.v2+json
             // TODO(alexr): The registry below is unreliable and hence disabled.
             // Consider re-enabling shall it become more stable.
             // "registry.cn-hangzhou.aliyuncs.com/acs-sample/alpine",
    -        "quay.io/coreos/alpine-sh" // manifest.v1+prettyjws
    +        // "quay.io/coreos/alpine-sh" // manifest.v1+prettyjws
           })));


    @@ -1349,7 +1349,7 @@ TEST_F(ProvisionerDockerTest, ROOT_INTERNET_CURL_ImageDigest)

       Image image;
       image.set_type(Image::DOCKER);
    -  image.mutable_docker()->set_name("library/alpine@" + digest);
    +  image.mutable_docker()->set_name("alpine");

       ContainerInfo* container = task.mutable_container();
       container->set_type(ContainerInfo::MESOS);
    ```

*   Modify `$SOURCE_ROOT/mesos/src/tests/containerizer/runtime_isolator_tests.cpp`:
    ```diff
    @@ -411,7 +411,7 @@ TEST_F(DockerRuntimeIsolatorTest, ROOT_INTERNET_CURL_NestedSimpleCommand)
           v1::createCommandInfo("/bin/ls", {"ls", "-al", "/"}));

       taskInfo.mutable_container()->CopyFrom(
    -      v1::createContainerInfo("library/alpine"));
    +      v1::createContainerInfo("alpine"));

       Future<Event::Update> updateStarting;
       Future<Event::Update> updateRunning;
    ```

*   Modify `$SOURCE_ROOT/mesos/src/tests/containerizer/cgroups_isolator_tests.cpp` __**(Ubuntu 19.04 only)**__
    ```diff
    diff --git a/src/tests/containerizer/cgroups_isolator_tests.cpp b/src/tests/containerizer/cgroups_isolator_tests.cpp
    index 957f72d78..a92e2cdba 100644
    --- a/src/tests/containerizer/cgroups_isolator_tests.cpp
    +++ b/src/tests/containerizer/cgroups_isolator_tests.cpp
    @@ -1763,7 +1763,7 @@ TEST_F(CgroupsIsolatorTest, ROOT_CGROUPS_MemoryBackward)

     // This test verifies the cgroups blkio statistics
     // of the container can be successfully retrieved.
    -TEST_F(CgroupsIsolatorTest, ROOT_CGROUPS_BlkioUsage)
    +TEST_F(CgroupsIsolatorTest, DISABLED_ROOT_CGROUPS_BlkioUsage)
     {
       Try<Owned<cluster::Master>> master = StartMaster();
       ASSERT_SOME(master);
    ```
    **Note:** Disabling `ROOT_CGROUPS_BlkioUsage` as it is flaky and currently fails on newer Linux kernel version.

#### 2.3) Run test cases

```bash
cd $SOURCE_ROOT/mesos/build
make check -k
```

_**NOTE:**_

_1. There are many test cases are fail intermittently. If this is the case, please run the test case individually as such below:_

```bash
cd $SOURCE_ROOT/mesos/build
./bin/mesos-tests.sh --gtest_filter=<test_case>
```

_2. In case of the following test case failures: `CgroupsAnyHierarchyWithCpuMemoryTest.ROOT_CGROUPS_Listen`, execute `swapoff -a` command on your machine._

_3.`ContainerizerTest.ROOT_CGROUPS_BalloonFramework` test case fails if 5432 port is already in use. Port can be changed in file `$SOURCE_ROOT/mesos/src/tests/balloon_framework_test.sh`_

_4. Test cases `CniIsolatorTest.ROOT_*`, `CniIsolatorPortMapperTest.ROOT_IPTABLES_NC_PortMapper`, `NetworkParam/DefaultExecutorCniTest.ROOT_VerifyContainerIP` and `DefaultContainerDNSInfo/DefaultContainerDNSCniTest.ROOT_VerifyDefaultDNS`
has been known to fail on SLES 12 for both s390x and x86. [https://issues.apache.org/jira/browse/MESOS-8364](https://issues.apache.org/jira/browse/MESOS-8364)_

## Step 3: Run Apache Mesos

#### 3.1) Start Master

```bash
cd $SOURCE_ROOT/mesos/build
sudo ./bin/mesos-master.sh --ip=<ip_address> --work_dir=/var/lib/mesos
```

#### 3.2) Start Slave

```bash
cd $SOURCE_ROOT/mesos/build
sudo ./bin/mesos-agent.sh --master=<ip_address>:5050 --work_dir=/var/lib/mesos
```

#### 3.3) Access Web UI

Open `https://<ip_address>:5050` in your browser to access Mesos UI.

## Reference:

[http://mesos.apache.org/](http://mesos.apache.org/)
