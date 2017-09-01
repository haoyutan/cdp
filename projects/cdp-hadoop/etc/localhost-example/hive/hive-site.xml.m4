<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?><!--
   Licensed to the Apache Software Foundation (ASF) under one or more
   contributor license agreements.  See the NOTICE file distributed with
   this work for additional information regarding copyright ownership.
   The ASF licenses this file to You under the Apache License, Version 2.0
   (the "License"); you may not use this file except in compliance with
   the License.  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-->
<configuration>
    <property>
        <name>hive.execution.engine</name>
        <value>mr</value>
    </property>
    <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>/user/CDP_USER/CDP_HOSTNAME/hive/warehouse</value>
    </property>

    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:derby://localhost:eval(CDP_PORT_BASE+100)/metadata_db;create=true</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>org.apache.derby.jdbc.ClientDriver</value>
    </property>

    <!-- for HiveServer2 -->
    <property>
        <name>hive.server2.thrift.bind.host</name>
        <value>CDP_HIVE_MASTER</value>
    </property>
    <property>
        <name>hive.server2.transport.mode</name>
        <value>binary</value>
    </property>
    <property>
        <name>hive.server2.thrift.port</name>
        <value>eval(CDP_PORT_BASE+110)</value>
    </property>
    <property>
        <name>hive.server2.thrift.http.port</name>
        <value>eval(CDP_PORT_BASE+111)</value>
    </property>
    <property>
        <name>hive.server2.enable.doAs</name>
        <value>false</value>
    </property>
</configuration>
