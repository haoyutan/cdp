# CloudDataPlatform Hadoop Distribution (CDP Hadoop)

## 1. Introduction

**CDP Hadoop** is a core package of **CloudDataPlatform (CDP)** developed by Deepera Co., Ltd. The ultimate goal of CDP is *making big data analytics extremely simple*.	 Towards this goal, we are intensively developing CDP Hadoop which may become *perhaps the most easy-to-deploy* Hadoop distribution in the world.

## 2. Get CDP Hadoop

### 2.1 Build from source

Currently, we can build CDP Hadoop from source by the following steps.

```
$ cd WORK_DIR
$ git clone THIS_REPOSITORY cdp-src
$ cd cdp-src/projects/cdp-hadoop
$ make build
```

If `make build` is successful, the installer direcotry `cdp-hadoop-VERSION` will be generated under `build`.

### 2.2 Fix download urls for dependencies

As we haven't set up an http or ftp server hosting the dependency packages, we need to manually modify the download urls before installation.

```
$ cd build/cdp-hadoop-VERSION
$ vim packages/.packages.ini
```

For each package, if you already have the distribution file locally, you need to replace `SOMEWHERE` with the actual path. Otherwise, you need to change the whole url to a download link.

**Note:** You may also manually directly download or copy the listed package files to `packages` and leave `.packages.ini` unmodified.

## 3. Quick start

### 3.1 Prepare

Before installation, please ensure your system meets the following requirements:

- Packages `m4` and `curl` are installed. They are runtime dependencies of the installer.
- SSH login by public key authentication is properly configured, i.e., you should be able to `ssh localhost` without password.

### 3.2 Install a local CDP Hadoop in 5 minutes

It is recommanded to run the installer from a temporary directory so that the generated log files won't mess up with the installer direcotry.

```
$ mv cdp-src/build/cdp-hadoop-VERSION ./
$ mkdir tmp
$ cd tmp
$ cp -r ../cdp-hadoop-VERSION/etc/localhost-example ./config-dir
$ export CDP_HOSTNAME=localhost
$ bash cdp-hadoop-VERSION/install-cdp-hadoop config-dir install
```

The default installation location is `/tmp/cdp/system` as specified in `config-dir/cluster.ini`. During the installation, the finish status of each task should be either *skip* or *ok*.

### 3.3 Load the environment settings

You should source the environment settings file `cdprc` each time you start a new terminal session.

~~~
$ source /tmp/cdp/system/etc/cdprc
~~~

### 3.4 Start and stop all CDP Hadoop services

To start all services:

~~~
$ cdp-hadoop-ctl start
~~~

To Stop all services:

~~~
$ cdp-hadoop-ctl stop
~~~

### 3.5 Uninstall CDP Hadoop

To uninstall CDP Hadoop:

~~~
$ cdp-hadoop-ctl uninstall
~~~

For safety reasons, the persistent data (files on HDFS, metadata in Hive metastore, etc.) will not be removed automatically. If you reinstall CDP Hadoop with the same configuration, the persistent data can be accessed normally.

Upon each uninstallation, the configuration directory will be backed up to `$HOME/.cdp/cdp-config-DATETIME`.

## 4. Gook luck and have fun!

## 5. Miscellaneous

### 5.1 Hadoop on Mac OSX

To fix the problem of 'Unable to load realm info from SCDynamicStore', we need to add the following lines to `hadoop-env.sh`:

~~~
export HADOOP_OPTS="${HADOOP_OPTS} -Djava.security.krb5.realm= `
                                  `-Djava.security.krb5.kdc= `
                                  `-Djava.security.krb5.conf=/dev/null"
~~~
