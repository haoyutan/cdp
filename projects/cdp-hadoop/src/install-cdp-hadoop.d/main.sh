#!/bin/bash


#-------------------------------------------------------------------------------
# Installation functions
#-------------------------------------------------------------------------------
_hadoop_print_info()
{
    local cdp_roles=""
    if [ "$CDP_IS_CLUSTER_MASTER" == "yes" ]; then
        cdp_roles+="cluster-master "
    fi
    if [ "$CDP_IS_CLUSTER_SLAVE" == "yes" ]; then
        cdp_roles+="cluster-slave "
    fi
    if [ "$CDP_IS_HDFS_MASTER" == "yes" ]; then
        cdp_roles+="hdfs-master "
    fi
    if [ "$CDP_IS_HDFS_SLAVE" == "yes" ]; then
        cdp_roles+="hdfs-slave "
    fi
    if [ "$CDP_IS_HIVE_MASTER" == "yes" ]; then
        cdp_roles+="hive-master "
    fi
    cdp_roles+="client"

    printf "[Information]\n`
           `  Configuration  : $CDP_CONFIG\n`
           `  CDP Components : $CDP_COMPONENTS\n`
           `  CDP Hostname   : $CDP_HOSTNAME\n`
           `  CDP User       : $CDP_USER\n`
           `  CDP Prefix     : $CDP_PREFIX\n`
           `  CDP Roles      : \n"
    for cdp_role in $cdp_roles; do
        printf "    $cdp_role\n"
    done
}


_hadoop_basic_install_init_data_dirs()
{
    local datalink_dir=$CDP_PREFIX/data
    mkdir -p $datalink_dir

    if [ "$CDP_IS_CLUSTER_MASTER" != "yes" ] && \
       [ "$CDP_IS_CLUSTER_SLAVE" != "yes" ]; then
        ms_logging_log "$CDP_HOSTNAME is not in the cluster. Skip."
        return 0
    fi

    local i=1
    for data_dir in $CDP_DATA_DIRS; do
        if [ ! -e "$data_dir" ]; then
            mkdir -p $data_dir
        fi
        ln -s $data_dir $datalink_dir/data$i
        i=$(expr $i + 1)
    done
}


_hadoop_basic_install_jdk_linux()
{
    ms_logging_log "Installing JDK for Linux..."

    cdp_packages_jdk_bin
    ms_target_task_run "Downloading $cdp_fn..." \
        "bash $MS_PROG_DIR/download-packages $MS_PROG_DIR/packages jdk_bin" \
        "! test -e $MS_PROG_DIR/packages/$cdp_fn"
    ms_die_on_error

    ms_target_task_run "Extracting JDK package..." \
        "install_package_to_opt ${cdp_fn/%.tar.gz/} jdk" \
        "! test -e $CDP_PREFIX/opt/jdk"
    ms_die_on_error
}


_hadoop_basic_install_jdk_osx()
{
    ms_logging_log "Installing JDK for OSX..."
    local java_home=$(/usr/libexec/java_home)
    if [ ! -e "$java_home" ]; then
        ms_die "JAVA_HOME returned by /usr/libexec/java_home is not valid."
    fi

    ms_target_task_run "Copying system JDK..." \
        "cp -r $java_home $CDP_PREFIX/opt/jdk" \
        "! test -e $CDP_PREFIX/opt/jdk"
    ms_die_on_error

    local policy_file=$CDP_PREFIX/opt/jdk/jre/lib/security/java.policy
    ms_target_task_run "Configuring JDK..." \
        "echo '// Added by $CDP_META_DIST_NAME' `
        `>$policy_file && `
        `echo 'grant { permission java.security.AllPermission; };' `
        `>>$policy_file" \
        "! grep 'CDP Hadoop' $policy_file"
    ms_die_on_error
}


_hadoop_basic_install_jdk()
{
    case $CDP_OS in
    osx)
        _hadoop_basic_install_jdk_osx;;
    *)
        _hadoop_basic_install_jdk_linux;;
    esac

    ms_target_task_run "Adding JDK configurations to cdprc..." \
        "rc_add_section_header JDK && `
        `rc_add 'export JAVA_HOME=\$CDP_PREFIX/opt/jdk' && `
        `rc_add 'export PATH=\$JAVA_HOME/bin:\$PATH'" \
        "! rc_contains_section JDK"
    ms_die_on_error
    export JAVA_HOME=$CDP_PREFIX/opt/jdk
    export PATH=$JAVA_HOME/bin:$PATH

    ms_target_task_run "Testing JDK installation..." \
        "test_installation $CDP_PREFIX/opt/jdk/bin/java -version"
    ms_die_on_error
}


_hadoop_basic_install_hadoop()
{
    cdp_packages_hadoop_bin
    ms_target_task_run "Downloading $cdp_fn..." \
        "bash $MS_PROG_DIR/download-packages $MS_PROG_DIR/packages hadoop_bin" \
        "! test -e $MS_PROG_DIR/packages/$cdp_fn"
    ms_die_on_error

    ms_target_task_run "Extracting Hadoop package..." \
        "install_package_to_opt ${cdp_fn/%.tar.gz/} hadoop" \
        "! test -e $CDP_PREFIX/opt/hadoop"
    ms_die_on_error

    ms_target_task_run "Adding Hadoop configurations to cdprc..." \
        "rc_add_section_header Hadoop && `
        `rc_add 'unset HADOOP_HOME' && `
        `rc_add 'export HADOOP_PREFIX=\$CDP_PREFIX/opt/hadoop' && `
        `rc_add 'export HADOOP_CONF_DIR=\$HADOOP_PREFIX/etc/hadoop' && `
        `rc_add 'export PATH=\$HADOOP_PREFIX/bin:`
                              `\$HADOOP_PREFIX/sbin:\$PATH'" \
        "! rc_contains_section Hadoop"
    ms_die_on_error
    unset HADOOP_HOME
    export HADOOP_PREFIX=$CDP_PREFIX/opt/hadoop
    export HADOOP_CONF_DIR=$HADOOP_PREFIX/etc/hadoop
    export PATH=$HADOOP_PREFIX/bin:$HADOOP_PREFIX/sbin:$PATH

    local hadoop_etc=$CDP_PREFIX/opt/hadoop/etc
    ms_target_task_run "Copying Hadoop configuration files..." \
        "rm -rf $hadoop_etc/hadoop.orig && `
        `mv $hadoop_etc/hadoop $hadoop_etc/hadoop.orig && `
        `cp -r $hadoop_etc/hadoop.orig $hadoop_etc/hadoop.cdp && `
        `cd $hadoop_etc && ln -s hadoop.cdp hadoop" \
        "! test -e $hadoop_etc/hadoop.cdp"
    ms_die_on_error

    ms_target_task_run "Generating Hadoop configuration files..." \
        "apply_cdp_m4_on_dir $CDP_CONFIG/hadoop $hadoop_etc/hadoop && `
        `mkdir -p $hadoop_etc/hadoop/.cdp && `
        `touch $hadoop_etc/hadoop/.cdp/hadoop-configured" \
        "! test -e $hadoop_etc/hadoop/.cdp/hadoop-configured"
    ms_die_on_error

    ms_target_task_run "Installing hadoop-ctl..." \
        "cp -r $MS_PROG_DIR/hadoop-ctl $CDP_PREFIX/bin/hadoop-ctl && `
        `chmod +x $CDP_PREFIX/bin/hadoop-ctl" \
        "! test -e $CDP_PREFIX/bin/hadoop-ctl"
    ms_die_on_error

    ms_target_task_run "Testing Hadoop installation..." \
        "test_installation $CDP_PREFIX/opt/hadoop/bin/hadoop version"
    ms_die_on_error
}


_hadoop_basic_install()
{
    ms_target_task_run "Initializing installation directory..." \
        "mkdir -p $CDP_PREFIX && cd $CDP_PREFIX && `
        `mkdir -p bin etc lib opt var tmp && mkdir -p var/run var/log" \
        "! test -e $CDP_PREFIX"
    ms_die_on_error

    ms_target_task_run "Initializing data directories..." \
        "_hadoop_basic_install_init_data_dirs" \
        "! test -e $CDP_PREFIX/data"
    ms_die_on_error

    ms_target_task_run "Installing cdp-config..." \
        "cp -r $CDP_CONFIG $CDP_PREFIX/etc/cdp-config" \
        "! test -e $CDP_PREFIX/etc/cdp-config"
    ms_die_on_error

    ms_target_task_run "Initializing cdprc..." \
        "rc_add '#!/bin/bash' && `
        `rc_add '' && rc_add '' && `
        `rc_add '# Note: The content of this file is generated by `
                `$CDP_META_DIST_NAME' && `
        `rc_add 'export CDP_PREFIX=$CDP_PREFIX' && `
        `rc_add 'export CDP_CONFIG=\$CDP_PREFIX/etc/cdp-config' && `
        `rc_add 'export CDP_HOSTNAME=$CDP_HOSTNAME' && `
        `rc_add 'export PATH=$CDP_PREFIX/bin:\$PATH'" \
        "! test -e $CDP_PREFIX/etc/cdprc"
    ms_die_on_error
    export CDP_PREFIX=$CDP_PREFIX
    export PATH=$CDP_PREFIX/bin:$PATH

    ms_target_task_run "Generating macro definition file..." \
        "create_cdp_config_m4 $CDP_PREFIX/etc/cdp.m4" \
        "! test -e $CDP_PREFIX/etc/cdp.m4"
    ms_die_on_error

    ms_target_task_run "Installing cdp-hadoop-ctl..." \
        "cp -f $MS_PROG_DIR/$MS_PROG $CDP_PREFIX/bin/cdp-hadoop-ctl && `
        `chmod +x $CDP_PREFIX/bin/cdp-hadoop-ctl" \
        "! test -e $CDP_PREFIX/bin/cdp-hadoop-ctl"

    _hadoop_basic_install_jdk
    _hadoop_basic_install_hadoop
}


_hadoop_basic_status()
{
    ms_target_check "Checking if JDK is installed..." \
        "$CDP_PREFIX/opt/jdk/bin/java -version"

    ms_target_check "Checking if Hadoop is installed..." \
        "$CDP_PREFIX/opt/hadoop/bin/hadoop version"
}


_hadoop_hdfs_install()
{
    ms_target_task_run "Generating HDFS configuration files..." \
        "apply_cdp_m4_on_dir $CDP_CONFIG/hdfs $HADOOP_PREFIX/etc/hadoop && `
        `mkdir -p $HADOOP_PREFIX/etc/hadoop/.cdp && `
        `touch $HADOOP_PREFIX/etc/hadoop/.cdp/hdfs-configured" \
        "! test -e $HADOOP_PREFIX/etc/hadoop/.cdp/hdfs-configured"
    ms_die_on_error

    ms_target_task_run "Adding HDFS configurations to cdprc..." \
        "rc_add_section_header HDFS && `
        `rc_add 'unset HADOOP_HDFS_HOME'" \
        "! rc_contains_section HDFS"
    ms_die_on_error
    unset HADOOP_HDFS_HOME

    local need_format="yes"
    if [ "$CDP_IS_HDFS_MASTER" == "yes" ]; then
        for name_dir in $CDP_NAMENODE_NAME_DIRS; do
            if [ -e "$name_dir" ]; then need_format="no"; break; fi
        done
    else
        need_format="no"
    fi
    ms_target_task_run "Formatting HDFS NameNode..." \
        "echo 'N' | hdfs namenode -format" \
        "test '$need_format' == 'yes'"
    ms_die_on_error

    _hadoop_hdfs_start
}


_hadoop_hdfs_start()
{
    ms_target_task_run "Starting HDFS NameNode..." \
        "$CDP_HADOOP_CTL_CMD namenode-start" \
        "test '$CDP_IS_HDFS_MASTER' == 'yes' && `
        `! $CDP_HADOOP_CTL_CMD namenode-status"
    ms_die_on_error

    ms_target_task_run "Starting HDFS DataNode..." \
        "bash $MS_PROG_DIR/hadoop-ctl $CDP_HOSTNAME datanode-start" \
        "test '$CDP_IS_HDFS_SLAVE' == 'yes' && `
        `! $CDP_HADOOP_CTL_CMD datanode-status"
    ms_die_on_error
}


_hadoop_hdfs_stop()
{
    ms_target_task_run "Stopping HDFS DataNode..." \
        "$CDP_HADOOP_CTL_CMD datanode-stop" \
        "test '$CDP_IS_HDFS_SLAVE' == 'yes' && `
        `$CDP_HADOOP_CTL_CMD datanode-status"
    ms_die_on_error

    ms_target_task_run "Stopping HDFS NameNode..." \
        "$CDP_HADOOP_CTL_CMD namenode-stop" \
        "test '$CDP_IS_HDFS_MASTER' == 'yes' && `
        `$CDP_HADOOP_CTL_CMD namenode-status"
    ms_die_on_error
}


_hadoop_hdfs_status()
{
    ms_target_check "Checking if HDFS is configured..." \
        "test -e $CDP_PREFIX/opt/hadoop/etc/hadoop/.cdp/hdfs-configured"

    if [ "$CDP_IS_HDFS_MASTER" ]; then
        ms_target_check "Checking if NameNode is started..." \
            "$CDP_HADOOP_CTL_CMD namenode-status"
    fi

    if [ "$CDP_IS_HDFS_SLAVE" ]; then
        ms_target_check "Checking if DataNode is started..." \
            "$CDP_HADOOP_CTL_CMD datanode-status"
    fi
}


_hadoop_yarn_install()
{
    ms_target_task_run "Generating Yarn configuration files..." \
        "apply_cdp_m4_on_dir $CDP_CONFIG/yarn $HADOOP_PREFIX/etc/hadoop && `
        `mkdir -p $HADOOP_PREFIX/etc/hadoop/.cdp && `
        `touch $HADOOP_PREFIX/etc/hadoop/.cdp/yarn-configured" \
        "! test -e $HADOOP_PREFIX/etc/hadoop/.cdp/yarn-configured"
    ms_die_on_error

    ms_target_task_run "Adding Yarn configurations to cdprc..." \
        "rc_add_section_header Yarn && `
        `rc_add 'unset HADOOP_YARN_HOME'" \
        "! rc_contains_section Yarn"
    ms_die_on_error
    unset HADOOP_Yarn_HOME

    _hadoop_yarn_start
}


_hadoop_yarn_start()
{
    ms_target_task_run "Starting Yarn ResourceManager..." \
        "$CDP_HADOOP_CTL_CMD resourcemanager-start" \
        "test '$CDP_IS_YARN_MASTER' == 'yes' && `
        `! $CDP_HADOOP_CTL_CMD resourcemanager-status"
    ms_die_on_error

    ms_target_task_run "Starting Yarn NodeManager..." \
        "$CDP_HADOOP_CTL_CMD nodemanager-start" \
        "test '$CDP_IS_YARN_SLAVE' == 'yes' && `
        `! $CDP_HADOOP_CTL_CMD nodemanager-status"
    ms_die_on_error

    ms_target_task_run "Starting Yarn TimelineServer..." \
        "$CDP_HADOOP_CTL_CMD timelineserver-start" \
        "test '$CDP_IS_YARN_MASTER' == 'yes' && `
        `! $CDP_HADOOP_CTL_CMD timelineserver-status"
    ms_die_on_error
}


_hadoop_yarn_stop()
{
    ms_target_task_run "Stopping Yarn TimelineServer..." \
        "$CDP_HADOOP_CTL_CMD timelineserver-stop" \
        "test '$CDP_IS_YARN_MASTER' == 'yes' && `
        `$CDP_HADOOP_CTL_CMD timelineserver-status"
    ms_die_on_error

    ms_target_task_run "Stopping Yarn NodeManager..." \
        "$CDP_HADOOP_CTL_CMD nodemanager-stop" \
        "test '$CDP_IS_YARN_SLAVE' == 'yes' && `
        `$CDP_HADOOP_CTL_CMD nodemanager-status"
    ms_die_on_error

    ms_target_task_run "Stopping Yarn ResourceManager..." \
        "$CDP_HADOOP_CTL_CMD resourcemanager-stop" \
        "test '$CDP_IS_YARN_MASTER' == 'yes' && `
        `$CDP_HADOOP_CTL_CMD resourcemanager-status"
    ms_die_on_error
}


_hadoop_yarn_status()
{
    ms_target_check "Checking if Yarn is configured..." \
        "test -e $CDP_PREFIX/opt/hadoop/etc/hadoop/.cdp/yarn-configured"

    if [ "$CDP_IS_YARN_MASTER" ]; then
        ms_target_check "Checking if TimelineServer is started..." \
            "$CDP_HADOOP_CTL_CMD timelineserver-status"
    fi

    if [ "$CDP_IS_YARN_MASTER" ]; then
        ms_target_check "Checking if ResourceManager is started..." \
            "$CDP_HADOOP_CTL_CMD resourcemanager-status"
    fi

    if [ "$CDP_IS_YARN_SLAVE" ]; then
        ms_target_check "Checking if NodeManager is started..." \
            "$CDP_HADOOP_CTL_CMD nodemanager-status"
    fi
}


_hadoop_tez_install()
{
    cdp_packages_tez_minimal_bin
    ms_target_task_run "Downloading $cdp_fn..." \
        "bash $MS_PROG_DIR/download-packages $MS_PROG_DIR/packages `
            `tez_minimal_bin" \
        "! test -e $MS_PROG_DIR/packages/$cdp_fn"
    ms_die_on_error

    ms_target_task_run "Installing local Tez library..." \
        "mkdir -p $CDP_PREFIX/opt/tez && `
        `tar zxf $MS_PROG_DIR/packages/$cdp_fn -C $CDP_PREFIX/opt/tez && `
        `cd $CDP_PREFIX/opt/tez && mkdir lib-unused && `
        `mv lib/slf4j-log4j* lib-unused/" \
        "! test -e $CDP_PREFIX/opt/tez"
    ms_die_on_error

    cdp_packages_tez_bin
    local tez_hdfs_dir="/user/$CDP_USER/apps/${cdp_fn/%.tar.gz/}"
    local tez_hdfs_package="$tez_hdfs_dir/$cdp_fn"
    ms_target_task_run "Downloading $cdp_fn..." \
        "bash $MS_PROG_DIR/download-packages $MS_PROG_DIR/packages tez_bin" \
        "! hdfs dfs -stat $tez_hdfs_package && `
        `! test -e $MS_PROG_DIR/packages/$cdp_fn"
    ms_die_on_error

    ms_target_task_run "Uploading $cdp_fn to HDFS..." \
        "hdfs dfs -mkdir -p $tez_hdfs_dir && `
        `hdfs dfs -put $MS_PROG_DIR/packages/$cdp_fn $tez_hdfs_package" \
        "! hdfs dfs -stat $tez_hdfs_package"
    ms_die_on_error

    ms_target_task_run "Updating macro definition file..." \
        "cdp_m4_add_definition CDP_HDFS_TEZ_PATH $tez_hdfs_package" \
        "! grep 'CDP_HDFS_TEZ_PATH' $CDP_PREFIX/etc/cdp.m4"
    ms_die_on_error

    ms_target_task_run "Generating Tez configuration files..." \
        "mkdir -p $CDP_PREFIX/opt/tez/conf && `
        `apply_cdp_m4_on_dir $CDP_CONFIG/tez $CDP_PREFIX/opt/tez/conf && `
        `mkdir -p $CDP_PREFIX/opt/tez/conf/.cdp && `
        `touch $CDP_PREFIX/opt/tez/conf/.cdp/tez-configured" \
        "! test -e $CDP_PREFIX/opt/tez/conf/.cdp/tez-configured"
    ms_die_on_error

    ms_target_task_run "Adding Tez configurations to cdprc..." \
        "rc_add_section_header Tez && `
        `rc_add 'export TEZ_CONF_DIR=\$CDP_PREFIX/opt/tez/conf' && `
        `rc_add 'export TEZ_JARS=\$CDP_PREFIX/opt/tez' && `
        `rc_add 'export HADOOP_CLASSPATH=\$TEZ_CONF_DIR:\$TEZ_JARS/*:`
            `\$TEZ_JARS/lib/*:\$HADOOP_CLASSPATH'" \
        "! rc_contains_section Tez"
    ms_die_on_error
    export TEZ_CONF_DIR=$CDP_PREFIX/opt/tez/conf
    export TEZ_JARS=$CDP_PREFIX/opt/tez
    export HADOOP_CLASSPATH="$TEZ_CONF_DIR:$TEZ_JARS/*:$TEZ_JARS/lib/*:`
                            `$HADOOP_CLASSPATH'"
}


_hadoop_tez_status()
{
    ms_target_check "Checking if Tez is installed..." \
        "test -e $CDP_PREFIX/opt/tez"
    ms_target_check "Checking if Tez is configured..." \
        "test -e $CDP_PREFIX/opt/tez/conf/.cdp/tez-configured"
}


_hadoop_hive_install()
{
    cdp_packages_hive_bin
    ms_target_task_run "Downloading $cdp_fn..." \
        "bash $MS_PROG_DIR/download-packages $MS_PROG_DIR/packages hive_bin" \
        "! test -e $MS_PROG_DIR/packages/$cdp_fn"
    ms_die_on_error

    ms_target_task_run "Extracting Hive package..." \
        "install_package_to_opt ${cdp_fn/%.tar.gz/} hive" \
        "! test -e $CDP_PREFIX/opt/hive"
    ms_die_on_error

    local src_dir=$CDP_PREFIX/opt/jdk/db/lib/
    local dst_dir=$CDP_PREFIX/opt/hive/lib/
    local jar1=derbyclient.jar
    local jar2=derbytools.jar
    ms_target_task_run "Installing Derby JDBC driver..." \
        "cp -f $src_dir/$jar1 $dst_dir/$jar1 && `
        `cp -f $src_dir/$jar2 $dst_dir/$jar2" \
        "! test -e $dst_dir/$jar1 || ! test -e $dst_dir/$jar2"
    ms_die_on_error

    ms_target_task_run "Generating Hive configuration files..." \
        "apply_cdp_m4_on_dir $CDP_CONFIG/hive $CDP_PREFIX/opt/hive/conf && `
        `mkdir -p $CDP_PREFIX/opt/hive/conf/.cdp && `
        `touch $CDP_PREFIX/opt/hive/conf/.cdp/hive-configured" \
        "test '$CDP_IS_HIVE_MASTER' == 'yes' && `
        `! test -e $CDP_PREFIX/opt/hive/conf/.cdp/hive-configured"
    ms_die_on_error

    ms_target_task_run "Adding Hive configurations to cdprc..." \
        "rc_add_section_header Hive && `
        `rc_add 'export HIVE_HOME=\$CDP_PREFIX/opt/hive' && `
        `rc_add 'export PATH=\$HIVE_HOME/bin:\$PATH'" \
        "! rc_contains_section Hive"
    ms_die_on_error
    export HIVE_HOME=$CDP_PREFIX/opt/hive
    export PATH=$HIVE_HOME/bin:$PATH

    _hadoop_hive_start
}


_hadoop_hive_start()
{
    ms_target_task_run "Starting Hive Metastore server..." \
        "$CDP_HADOOP_CTL_CMD metastore-start" \
        "test '$CDP_IS_HIVE_MASTER' == 'yes' && `
        `! $CDP_HADOOP_CTL_CMD metastore-status"
    ms_die_on_error

    ms_target_task_run "Initializing Hive Metastore database..." \
        "hive -e 'show databases;' && `
        `mkdir -p $CDP_HIVE_METASTORE_DIR/.cdp && `
        `touch $CDP_HIVE_METASTORE_DIR/.cdp/metastore-initialized" \
        "test '$CDP_IS_HIVE_MASTER' == 'yes' && `
        `! test -e $CDP_HIVE_METASTORE_DIR/.cdp/metastore-initialized"
    ms_die_on_error

    ms_target_task_run "Starting HiveServer2..." \
        "$CDP_HADOOP_CTL_CMD hiveserver2-start" \
        "test '$CDP_IS_HIVE_MASTER' == 'yes' && `
        `! $CDP_HADOOP_CTL_CMD hiveserver2-status"
    ms_die_on_error
}


_hadoop_hive_stop()
{
    ms_target_task_run "Stopping HiveServer2..." \
        "$CDP_HADOOP_CTL_CMD hiveserver2-stop" \
        "test '$CDP_IS_HIVE_MASTER' == 'yes' && `
        `$CDP_HADOOP_CTL_CMD hiveserver2-status"
    ms_die_on_error

    ms_target_task_run "Stopping Hive Metastore..." \
        "$CDP_HADOOP_CTL_CMD metastore-stop" \
        "test '$CDP_IS_HIVE_MASTER' == 'yes' && `
        `$CDP_HADOOP_CTL_CMD metastore-status"
    ms_die_on_error
}


_hadoop_hive_status()
{
    ms_target_check "Checking if Hive is installed..." \
        "test -e $CDP_PREFIX/opt/hive"

    if [ "$CDP_IS_HIVE_MASTER" == "yes" ]; then
        ms_target_check "Checking if Hive is configured..." \
            "test -e $CDP_PREFIX/opt/hive/conf/.cdp/hive-configured"
        ms_target_check "Checking if Hive Metastore is started..." \
            "$CDP_HADOOP_CTL_CMD metastore-status"
        ms_target_check "Checking if HiveServer2 is started..." \
            "$CDP_HADOOP_CTL_CMD hiveserver2-status"
    fi
}


hadoop_install()
{
    ms_ini_parse $MS_PROG_DIR/packages/.packages.ini cdp_packages

    ms_output_block begin "Install $CDP_META_DIST_NAME."
    _hadoop_print_info

    for component in $CDP_COMPONENTS; do
        printf "\n[Install $component]\n"
        _hadoop_${component}_install
    done

    ms_output_block end
}


hadoop_uninstall()
{
    ms_output_block begin "Uninstall $CDP_META_DIST_NAME."

    local backup_dir=$HOME/.cdp
    local backup_name="cdp-config-$(ms_datetime simple)"
    printf "`
`NOTE: Uninstalling $CDP_META_DIST_NAME will only remove the software.\n`
`      All your data in data directories ($CDP_DATA_DIRS)\n`
`      will not be removed.\n\n`
`      If you reinstall $CDP_META_DIST_NAME with the same configuration,\n`
`      the data should be able to access normally.\n\n`
`      A backup of the current configuration will be saved to\n`
`      $backup_dir/$backup_name.\n\n"

    _hadoop_print_info
    _hadoop_stop

    printf "\n[Uninstall]\n"
    ms_target_task_run "Saving configuration direcotry..." \
        "mkdir -p $backup_dir && `
        `cp -r $CDP_PREFIX/etc/cdp-config $backup_dir/$backup_name" \
        "test -e $CDP_PREFIX/etc/cdp-config"
    ms_die_on_error

    ms_target_task_run "Removing installation direcotry..." \
        "rm -rf $CDP_PREFIX" \
        "test -e $CDP_PREFIX"
    ms_die_on_error

    ms_output_block end
}


hadoop_start()
{
    ms_output_block begin "Start $CDP_META_DIST_NAME."
    _hadoop_print_info

    for component in $CDP_COMPONENTS; do
        if ms_declared_function _hadoop_${component}_start; then
            printf "\n[Start $component]\n"
            _hadoop_${component}_start
        fi
    done

    ms_output_block end
}


_hadoop_stop()
{
    local cdp_components=($CDP_COMPONENTS)
    for i in "${!cdp_components[@]}"; do
        local component=${cdp_components[${#cdp_components[*]} - $i]}
        if ms_declared_function _hadoop_${component}_stop; then
            printf "\n[Stop $component]\n"
            _hadoop_${component}_stop
        fi
    done
}


hadoop_stop()
{
    ms_output_block begin "Stop $CDP_META_DIST_NAME."
    _hadoop_print_info
    _hadoop_stop
    ms_output_block end
}


hadoop_status()
{
    ms_output_block begin "Status of $CDP_META_DIST_NAME."
    _hadoop_print_info

    printf "\n[Installation]\n"
    ms_target_check "Checking if $CDP_META_DIST_NAME is installed..." \
        "test -d $CDP_PREFIX"

    for component in $CDP_COMPONENTS; do
        if ms_declared_function _hadoop_${component}_status; then
            printf "\n[Status of $component]\n"
            _hadoop_${component}_status
        fi
    done

    ms_output_block end
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Main and helper functions
#-------------------------------------------------------------------------------
_main_installer()
{
    local utility_commands="install uninstall start stop status"
    ms_utility_setup "$MS_NS CONFIG_DIR" "hadoop" "$utility_commands"

    if [ -z "$CDP_HOSTNAME" ]; then
        ms_die "Environment variable CDP_HOSTNAME is not set."
    fi
    ms_logging_assign "CDP_HOSTNAME" "$CDP_HOSTNAME"
    export CDP_HOSTNAME

    if [  "$#" -gt "1" ]; then
        ms_logging_assign "CDP_CONFIG" "$1"
        export CDP_CONFIG
        shift
    else
        >&2 ms_utility_print_help
        exit $MS_EC_WRONG_ARGS
    fi

    if [ ! -d "$CDP_CONFIG" ]; then
        ms_die "$CDP_CONFIG does not exist or is not a directory."
    fi

    load_cdp_config $CDP_CONFIG
    ms_logging_assign "CDP_HADOOP_CTL_CMD" \
                      "bash $MS_PROG_DIR/hadoop-ctl $CDP_HOSTNAME"
    
    ms_utility_run "$@"
}


_main_ctl()
{
    local utility_commands="start stop status uninstall"
    ms_utility_setup "$MS_NS" "hadoop" "$utility_commands"

    if [ ! -e "$MS_PROG_DIR/../etc/cdprc" ]; then
        ms_die "Cannot find $MS_PROG_DIR/../etc/cdprc."
    fi

    source $MS_PROG_DIR/../etc/cdprc

    if [ -z "$CDP_CONFIG" ]; then
        ms_die "Environment variable CDP_CONFIG is not set."
    elif [ ! -d "$CDP_CONFIG" ]; then
        ms_die "$CDP_CONFIG does not exist or is not a directory."
    fi

    load_cdp_config $CDP_CONFIG
    ms_logging_assign "CDP_HADOOP_CTL_CMD" \
                      "bash $MS_PROG_DIR/hadoop-ctl $CDP_HOSTNAME"

    ms_utility_run "$@"
}


main()
{
    ms_import logging
    ms_import target
    ms_import utility
    ms_import ini

    ms_logging_setup $MS_WORK_DIR/$MS_NS.log

    if [ "$MS_PROG" == "cdp-hadoop-ctl" ]; then
        _main_ctl "$@"
    else
        _main_installer "$@"
    fi
}
#-------------------------------------------------------------------------------
