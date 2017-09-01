#!/bin/bash


#-------------------------------------------------------------------------------
# Metadata
#-------------------------------------------------------------------------------
CDP_META_NAME="CDP Hadoop"
CDP_META_FULL_NAME="CloudDataPlatform Hadoop Distribution"
CDP_META_PACKAGE_NAME="cdp-hadoop"
CDP_META_VERSION="0.9.0"
CDP_META_DIST_NAME="$CDP_META_NAME $CDP_META_VERSION"

cdp_meta_dump()
{
    echo "Name        : $CDP_META_NAME"
    echo "FullName    : $CDP_META_FULL_NAME"
    echo "PackageName : $CDP_META_PACKAGE_NAME"
    echo "Version     : $CDP_META_VERSION"
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Functions handling CDP Hadoop configuration files
#-------------------------------------------------------------------------------
_array_subset()
{
    local array=($1)
    local indexes=($2)
    local subarray=()

    for index in ${indexes[*]}; do
        subarray+=(${array[$index]})
    done
    echo ${subarray[*]}
}

load_cdp_config()
{
    local cdp_config="$1"
    ms_ini_parse $cdp_config/cluster.ini cdp_config


    cdp_config_default

    if [ -z "$cdp_os" ]; then
        if [ -e "/Applications" ]; then cdp_os=osx; else cdp_os=linux; fi
    fi
    ms_logging_assign "CDP_OS"                 "$cdp_os"

    cdp_user=${cdp_user:-"$USER"}
    ms_logging_assign "CDP_USER"               "$cdp_user"

    ms_logging_assign "CDP_CLUSTER_MASTER"     "$cdp_cluster_master"
    ms_logging_assign "CDP_CLUSTER_SLAVES"     "${cdp_cluster_slaves[*]}"
    ms_logging_assign "CDP_COMPONENTS"         "${cdp_components[*]}"
    ms_logging_assign "CDP_PREFIX"             "$cdp_prefix"
    ms_logging_assign "CDP_DATA_DIRS"          "${cdp_data_dirs[*]}"
    ms_logging_assign "CDP_PORT_BASE"          "$cdp_port_base"

    ms_logging_assign "CDP_HDFS_MASTER" \
                      "${cdp_hdfs_master:-$CDP_CLUSTER_MASTER}"
    ms_logging_assign "CDP_HDFS_SLAVES" \
                      "${cdp_hdfs_slaves[*]:-$CDP_CLUSTER_SLAVES}"

    ms_logging_assign "CDP_YARN_MASTER" \
                      "${cdp_yarn_master:-$CDP_CLUSTER_MASTER}"
    ms_logging_assign "CDP_YARN_SLAVES" \
                      "${cdp_yarn_slaves[*]:-$CDP_CLUSTER_SLAVES}"

    ms_logging_assign "CDP_HIVE_MASTER" \
                      "${cdp_hive_master:-$CDP_CLUSTER_MASTER}"

    cdp_config_hdfs_master
    local name_dirs=$(_array_subset "$CDP_DATA_DIRS" \
                                    "${cdp_namenode_name_dirs[*]}")
    name_dirs=($name_dirs)
    name_dirs=(${name_dirs[*]/%/\/hadoop\/dfs\/nn})
    name_dirs=${name_dirs[*]}
    ms_logging_assign "CDP_NAMENODE_NAME_DIRS" "$name_dirs"

    cdp_config_hdfs_slave
    local data_dirs=$(_array_subset "$CDP_DATA_DIRS" \
                                    "${cdp_datanode_data_dirs[*]}")
    data_dirs=($data_dirs)
    data_dirs=(${data_dirs[*]/%/\/hadoop\/dfs\/dn})
    data_dirs=${data_dirs[*]}
    ms_logging_assign "CDP_DATANODE_DATA_DIRS" "$data_dirs"

    cdp_config_hive_master
    ms_logging_assign "CDP_HIVE_METASTORE_DIR" \
                      "${cdp_data_dirs[$cdp_hive_metastore_dir]}/hadoop/hive"

    # Derived variables
    ms_logging_assign "CDP_HADOOP_DAEMON_CMD" \
                      "$CDP_PREFIX/opt/hadoop/sbin/hadoop-daemon.sh"
    ms_logging_assign "CDP_RC"                 "$CDP_PREFIX/etc/cdprc"
    ms_logging_assign "CDP_IS_CLUSTER_MASTER"  "$(is_cluster_master)"
    ms_logging_assign "CDP_IS_CLUSTER_SLAVE"   "$(is_cluster_slave)"
    ms_logging_assign "CDP_IS_HDFS_MASTER"     "$(is_hdfs_master)"
    ms_logging_assign "CDP_IS_HDFS_SLAVE"      "$(is_hdfs_slave)"
    ms_logging_assign "CDP_IS_YARN_MASTER"     "$(is_yarn_master)"
    ms_logging_assign "CDP_IS_YARN_SLAVE"      "$(is_yarn_slave)"
    ms_logging_assign "CDP_IS_HIVE_MASTER"     "$(is_hive_master)"
}


is_master()
{
    local system=${1:-"CLUSTER"}
    local cdp_hostname=${2:-${CDP_HOSTNAME:-$HOSTNAME}}
    eval "test \"$cdp_hostname\" == \"\$CDP_${system}_MASTER\"" \
        && test "$CDP_USER" == "$USER"
    ms_echo_yn
}

is_slave()
{
    local system=${1:-"CLUSTER"}
    local cdp_hostname=${2:-${CDP_HOSTNAME:-$HOSTNAME}}
    eval "ms_word_in_string \"$cdp_hostname\" \"\$CDP_${system}_SLAVES\"" \
        && test "$CDP_USER" == "$USER"
    ms_echo_yn
}

is_cluster_master()
{
    is_master "CLUSTER" "$1"
}

is_cluster_slave()
{
    is_slave "CLUSTER" "$1"
}

is_hdfs_master()
{
    is_master "HDFS" "$1"
}

is_hdfs_slave()
{
    is_slave "HDFS" "$1"
}

is_yarn_master()
{
    is_master "YARN" "$1"
}

is_yarn_slave()
{
    is_slave "YARN" "$1"
}

is_hive_master()
{
    is_master "HIVE" "$1"
}


_m4_define()
{
    local name="$1"
    local value="$2"
    if [ -z "$value" ]; then
        eval "value=\$$name"
    fi

    printf "define(%s, %s)\n" "\`$name'" "\`$value'"
}

create_cdp_config_m4()
{
    local m4_file="$1"
    if [ -z "$m4_file" ]; then
        ms_die "No output file."
    else
        rm -rf $m4_file
    fi

    >>$m4_file printf "divert(-1)\n"
    local scalar_vars="CDP_HOSTNAME CDP_USER CDP_PREFIX CDP_PORT_BASE \
                       CDP_HDFS_MASTER CDP_YARN_MASTER CDP_HIVE_MASTER \
                       CDP_HIVE_METASTORE_DIR"
    for name in $scalar_vars; do
        >>$m4_file _m4_define $name
    done

    local vector_vars="CDP_HDFS_SLAVES CDP_YARN_SLAVES \
                       CDP_NAMENODE_NAME_DIRS CDP_DATANODE_DATA_DIRS"
    local value=""
    for name in $vector_vars; do
        eval "value=\${$name/\ /,}"
        >>$m4_file _m4_define $name "$value"
    done
    >>$m4_file printf "divert(1)"
}
#-------------------------------------------------------------------------------
