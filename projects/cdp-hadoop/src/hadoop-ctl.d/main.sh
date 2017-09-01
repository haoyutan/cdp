#!/bin/bash


#-------------------------------------------------------------------------------
# Utility definitions
#-------------------------------------------------------------------------------
ssh_exec() {
    local cmd="source $CDP_PREFIX/etc/cdprc; $*"
    $CDP_SSH_CMD "$cmd"
}


_jps_exists() {
    local process_name="$1"
    ssh_exec jps | awk '{print $2}' | grep -q "^$process_name"
}


_jps_kill() {
    local process_name="$1"

    pid="$(ssh_exec jps | grep $process_name | awk '{print $1}')"
    if [ "$pid" != "" ]; then
        ssh_exec kill $pid
    fi

    if $(_jps_exists $process_name); then
        ssh_exec kill -9 $pid
    fi

    if $(_jps_exists $process_name); then
        ms_debug_info "WARNING: Cannot kill $process_name on $CDP_HOST."
        return 1
    fi

    return 0
}


_check_status() {
    local service_name="$1"
    local process_name="${2:-$service_name}"
    ms_target_check "Checking if $CDP_HOST - $service_name is started..." \
        "_jps_exists $process_name"
}


_start_daemon() {
    local service_name="$1"
    local script_name="$2"
    local daemon_name="$3"
    ms_target_task_run "Starting $CDP_HOST - $service_name..." \
        "ssh_exec $CDP_HADOOP_DAEMON_CMD --script $script_name `
            `start $daemon_name" \
        "! hadoop_ctl_${daemon_name}_status"
}


_stop_daemon() {
    local service_name="$1"
    local script_name="$2"
    local daemon_name="$3"
    ms_target_task_run "Stopping $CDP_HOST - $service_name..." \
        "ssh_exec $CDP_HADOOP_DAEMON_CMD --script $script_name `
            `stop $daemon_name" \
        "hadoop_ctl_${daemon_name}_status"
    if hadoop_ctl_${daemon_name}_status >/dev/null 2>&1; then
        ms_debug_info "Cannot elegantly stop $CDP_HOST - $service_name. Kill it."
        _jps_kill $service_name
    fi
}


hadoop_ctl_host_status() {
    ms_target_check "Checking pinging $CDP_HOST..." \
        "ping -c 2 $CDP_HOST"
}


hadoop_ctl_namenode_status() {
    _check_status "NameNode"
}


hadoop_ctl_namenode_start() {
    _start_daemon "NameNode" "hdfs" "namenode"
}


hadoop_ctl_namenode_stop() {
    _stop_daemon "NameNode" "hdfs" "namenode"
}


hadoop_ctl_datanode_status() {
    _check_status "DataNode"
}


hadoop_ctl_datanode_start() {
    _start_daemon "DataNode" "hdfs" "datanode"
}


hadoop_ctl_datanode_stop() {
    _stop_daemon "DataNode" "hdfs" "datanode"
}


hadoop_ctl_resourcemanager_status() {
    _check_status "ResourceManager"
}


hadoop_ctl_resourcemanager_start() {
    _start_daemon "ResourceManager" "yarn" "resourcemanager"
}


hadoop_ctl_resourcemanager_stop() {
    _stop_daemon "ResourceManager" "yarn" "resourcemanager"
}


hadoop_ctl_nodemanager_status() {
    _check_status "NodeManager"
}


hadoop_ctl_nodemanager_start() {
    _start_daemon "NodeManager" "yarn" "nodemanager"
}


hadoop_ctl_nodemanager_stop() {
    _stop_daemon "NodeManager" "yarn" "nodemanager"
}


hadoop_ctl_timelineserver_status() {
    _check_status "ApplicationHistoryServer"
}


hadoop_ctl_timelineserver_start() {
    _start_daemon "ApplicationHistoryServer" "yarn" "timelineserver"
}


hadoop_ctl_timelineserver_stop() {
    _stop_daemon "ApplicationHistoryServer" "yarn" "timelineserver"
}


hadoop_ctl_metastore_status() {
    _check_status "Hive Metastore" "NetworkServerControl"
}


hadoop_ctl_metastore_start() {
    local derby_address=$(cat $CDP_PREFIX/opt/hive/conf/hive-site.xml `
                         `| grep "jdbc:derby" | head -1 `
                         `| sed  "s@.*jdbc:derby://\([^:]*:[0-9]*\).*@\1@")
    local derby_host=${derby_address/%:*/}
    local derby_port=${derby_address/#*:/}

    if [ -z "$derby_host" ]; then
        ms_die "Failed extracting Derby host from hive-site.xml."
    elif [ -z "$derby_port" ]; then
        ms_die "Failed extracting Derby port from hive-site.xml."
    fi

    ms_target_task_run "Starting $CDP_HOST - Hive Metastore..." \
        "ssh_exec `
            `'mkdir -p $CDP_HIVE_METASTORE_DIR;`
             `cd $CDP_HIVE_METASTORE_DIR;`
             `nohup $CDP_PREFIX/opt/jdk/db/bin/startNetworkServer `
                 `-h $derby_host -p $derby_port `
             `>$CDP_PREFIX/var/log/hive-metastore.out 2>&1 &'" \
        "! hadoop_ctl_metastore_status"
}


hadoop_ctl_metastore_stop() {
    ms_target_task_run "Stopping $CDP_HOST - Hive Metastore..." \
        "_jps_kill NetworkServerControl" \
        "hadoop_ctl_metastore_status"
}


hadoop_ctl_hiveserver2_status() {
    _check_status "HiveServer2" "RunJar"
}


hadoop_ctl_hiveserver2_start() {
    ms_target_task_run "Starting $CDP_HOST - HiveServer2..." \
        "ssh_exec `
            `'nohup $CDP_PREFIX/opt/hive/bin/hive --service hiveserver2 `
             `>$CDP_PREFIX/var/log/hiveserver2.out 2>&1 &'" \
        "! hadoop_ctl_hiveserver2_status"
}


hadoop_ctl_hiveserver2_stop() {
    ms_target_task_run "Stopping $CDP_HOST - HiveServer2..." \
        "_jps_kill RunJar" \
        "hadoop_ctl_hiveserver2_status"
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Main and helper functions
#-------------------------------------------------------------------------------
main() {
    ms_import logging
    ms_import target
    ms_import utility
    ms_import ini

    ms_logging_setup $MS_WORK_DIR/$MS_NS.log
    ms_utility_setup "hadoop-ctl HOST" "hadoop_ctl" \
        "host-status \
         namenode-status namenode-start namenode-stop \
         datanode-status datanode-start datanode-stop \
         resourcemanager-status resourcemanager-start resourcemanager-stop \
         nodemanager-status nodemanager-start nodemanager-stop \
         timelineserver-status timelineserver-start timelineserver-stop \
         metastore-status metastore-start metastore-stop \
         hiveserver2-status hiveserver2-start hiveserver2-stop"

    if [ -z "$CDP_CONFIG" ]; then
        ms_die "Environment variable CDP_CONFIG is not set."
    fi

    if [ -z "$1" ]; then
        >&2 ms_utility_print_help
        ms_die "Wrong arguments." $MS_EC_WRONG_ARGS
    fi

    load_cdp_config $CDP_CONFIG

    CDP_HOST="$1"
    CDP_SSH_CMD="ssh $CDP_USER@$CDP_HOST"
    ms_logging_log "CDP_HOST=$CDP_HOST"
    ms_logging_log "CDP_SSH_CMD=$CDP_SSH_CMD"

    shift
    ms_utility_run "$@"
}
#-------------------------------------------------------------------------------
