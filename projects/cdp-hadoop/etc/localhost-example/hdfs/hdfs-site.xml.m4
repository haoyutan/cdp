<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <!-- for namenode -->
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>CDP_NAMENODE_NAME_DIRS</value>
    </property>
    <property>
        <name>dfs.blocksize</name>
        <value>67108864</value>
    </property>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>

    <!-- for datanode -->
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>CDP_DATANODE_DATA_DIRS</value>
    </property>

    <!-- bind-addresses and ports for namenode -->
    <property>
        <name>dfs.namenode.rpc-bind-host</name>
        <value>CDP_HDFS_MASTER</value>
    </property>
    <property>
        <name>dfs.namenode.servicerpc-bind-host</name>
        <value>CDP_HDFS_MASTER</value>
    </property>
    <property>
        <name>dfs.namenode.http-bind-host</name>
        <value>CDP_HDFS_MASTER</value>
    </property>
    <property>
        <name>dfs.namenode.https-bind-host</name>
        <value>CDP_HDFS_MASTER</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+1)</value>
    </property>
    <property>
        <name>dfs.namenode.https-address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+2)</value>
    </property>
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+11)</value>
    </property>
    <property>
        <name>dfs.namenode.secondary.https-address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+12)</value>
    </property>
    <property>
        <name>dfs.namenode.backup.address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+21)</value>
    </property>
    <property>
        <name>dfs.namenode.backup.http-address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+22)</value>
    </property>

    <!-- bind-addresses and ports for datanode -->
    <property>
        <name>dfs.datanode.hostname</name>
        <value>CDP_HOSTNAME</value>
    </property>
    <property>
        <name>dfs.datanode.address</name>
        <value>${dfs.datanode.hostname}:eval(CDP_PORT_BASE+25)</value>
    </property>
    <property>
        <name>dfs.datanode.http.address</name>
        <value>${dfs.datanode.hostname}:eval(CDP_PORT_BASE+26)</value>
    </property>
    <property>
        <name>dfs.datanode.https.address</name>
        <value>${dfs.datanode.hostname}:eval(CDP_PORT_BASE+27)</value>
    </property>
    <property>
        <name>dfs.datanode.ipc.address</name>
        <value>${dfs.datanode.hostname}:eval(CDP_PORT_BASE+28)</value>
    </property>

    <!-- bind-address and ports for others -->
    <property>
        <name>dfs.journalnode.rpc-address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+40)</value>
    </property>
    <property>
        <name>dfs.journalnode.http-address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+41)</value>
    </property>
    <property>
        <name>dfs.journalnode.https-address</name>
        <value>CDP_HDFS_MASTER:eval(CDP_PORT_BASE+42)</value>
    </property>
</configuration>
