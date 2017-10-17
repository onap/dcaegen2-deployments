# ============LICENSE_START====================================================
# org.onap.dcae
# =============================================================================
# Copyright (c) 2017 AT&T Intellectual Property. All rights reserved.
# =============================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END======================================================

set -x
#
# get configuration
#
CODE_SOURCE=$1
CODE_VERSION=$2
CLUSTER_INDEX=$3
CLUSTER_SIZE=$4
CLUSTER_FQDNS=$5
CLUSTER_LOCAL_IPS=$6
CLUSTER_FLOATING_IPS=$7
DATACENTER=$8
REGISTERED_NAME=$9
export JAVA_HOME=/usr/lib/jvm/default-java
md5sum /root/.sshkey/id_rsa | awk '{ print $1 }' >/root/.mysqlpw
chmod 400 /root/.mysqlpw
#
# enable outside apt repositories
#
wget -qO- http://public-repo-1.hortonworks.com/HDP/ubuntu16/2.x/updates/2.6.0.3/hdp.list >/etc/apt/sources.list.d/hdp.list
wget -qO- http://repository.cask.co/ubuntu/precise/amd64/cdap/4.1/cask.list >/etc/apt/sources.list.d/cask.list
wget -qO- http://repository.cask.co/ubuntu/precise/amd64/cdap/4.1/pubkey.gpg | apt-key add -
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com B9733A7A07513CAD
apt-get update
#
# install software from apt repositories
#
apt-get install -y default-jdk hadoop-hdfs hadoop-mapreduce hive hbase libsnappy-dev liblzo2-dev hadooplzo spark-master spark-python zip unzip
usermod -a -G hadoop hive
if [ $CLUSTER_INDEX -lt 3 ]
then
  apt-get install -y zookeeper-server
  cat <<!EOF >>/etc/zookeeper/conf/zookeeper-env.sh
export JAVA_HOME=/usr/lib/jvm/default-java
export ZOOCFGDIR=/etc/zookeeper/conf
export ZOO_LOG_DIR=/var/log/zookeeper
export ZOOPIDFILE=/var/run/zookeeper/zookeeper_server.pid
!EOF
  mkdir -p /var/lib/zookeeper
  chown zookeeper:zookeeper /var/lib/zookeeper
  cp /usr/hdp/current/zookeeper-server/etc/init.d/zookeeper-server /etc/init.d/.
  update-rc.d zookeeper-server defaults
  service zookeeper-server start
fi
if [ $CLUSTER_INDEX -eq 2 ]
then
  debconf-set-selections <<!
mysql-server mysql-server/root_password password $(cat /root/.mysqlpw)
!
  debconf-set-selections <<!
mysql-server mysql-server/root_password_again password $(cat /root/.mysqlpw)
!
  apt-get install -y cdap cdap-cli cdap-gateway cdap-kafka cdap-master cdap-security cdap-ui mysql-server mysql-connector-java
set +x
echo + mysql_secure_installation --use-default
mysql_secure_installation --use-default --password=$(cat /root/.mysqlpw)
set -x
  mysql_install_db
  cp /usr/share/java/mysql-connector-java-*.jar /usr/hdp/current/hive-client/lib/.
  mkdir -p /usr/lib/hive/logs
  chown -R hive:hadoop /usr/lib/hive
  chmod -R 755 /usr/lib/hive
fi
#
# make directories
#
mkdir -p /hadoop/hdfs/journalnode/cl /hadoop/hdfs/namenode /hadoop/hdfs/data /etc/hadoop/conf /hadoop/yarn/local /hadoop/yarn/log /usr/lib/hadoop/logs /usr/lib/hadoop-mapreduce/logs /usr/lib/hadoop-yarn/logs /usr/lib/hbase/logs /etc/cdap/conf
#
# set up config files
#
HDPVER=$(ls /usr/hdp | grep -v current)
echo -Dhdp.version=$HDPVER >/usr/hdp/current/spark-client/conf/java-opts
echo "export OPTS=\"\${OPTS} -Dhdp.version=$HDPVER\"" >>/etc/cdap/conf/cdap-env.sh
cat >/etc/profile.d/hadoop.sh <<'!EOF'
HADOOP_PREFIX=/usr/hdp/current/hadoop-client
HADOOP_YARN_HOME=/usr/hdp/current/hadoop-yarn-nodemanager
HADOOP_HOME=/usr/hdp/current/hadoop-client
HADOOP_COMMON_HOME=$HADOOP_HOME
HADOOP_CONF_DIR=/etc/hadoop/conf
HADOOP_HDFS_HOME=/usr/hdp/current/hadoop-hdfs-namenode
HADOOP_LIBEXEC_DIR=$HADOOP_HOME/libexec
YARN_LOG_DIR=/usr/lib/hadoop-yarn/logs
HADOOP_LOG_DIR=/usr/lib/hadoop/logs
JAVA_HOME=/usr/lib/jvm/default-java
JAVA=$JAVA_HOME/bin/java
PATH=$PATH:$HADOOP_HOME/bin
HBASE_LOG_DIR=/usr/lib/hbase/logs
HADOOP_MAPRED_LOG_DIR=/usr/lib/hadoop-mapreduce/logs
HBASE_CONF_DIR=/etc/hbase/conf
export HADOOP_PREFIX HADOOP_HOME HADOOP_COMMON_HOME HADOOP_CONF_DIR HADOOP_HDFS_HOME JAVA_HOME PATH HADOOP_LIBEXEC_DIR JAVA JARN_LOG_DIR HADOOP_LOG_DIR HBASE_LOG_DIR HADOOP_MAPRED_LOG_DIR HBASE_CONF_DIR
!EOF
chmod 755 /etc/profile.d/hadoop.sh
cat </etc/profile.d/hadoop.sh >>/etc/hadoop/conf/hadoop-env.sh
mv /root/.sshkey /var/lib/hadoop-hdfs/.ssh
cp /var/lib/hadoop-hdfs/.ssh/id_rsa.pub /var/lib/hadoop-hdfs/.ssh/authorized_keys
>/etc/hadoop/conf/dfs.exclude
>/etc/hadoop/conf/yarn.exclude
chown -R hdfs:hadoop /var/lib/hadoop-hdfs/.ssh /hadoop /usr/lib/hadoop
chown -R yarn:hadoop /usr/lib/hadoop-yarn /hadoop/yarn
chown -R mapred:hadoop /usr/lib/hadoop-mapreduce
chown -R hbase:hbase /usr/lib/hbase
chmod 700 /var/lib/hadoop-hdfs/.ssh
chmod 600 /var/lib/hadoop-hdfs/.ssh/*
sed -i -e '/maxClientCnxns/d' /etc/zookeeper/conf/zoo.cfg

cat >/tmp/init.py <<!EOF
import os
with open('/root/.mysqlpw', 'r') as f:
  mysqlpw = f.readline().strip()
myid=int('$CLUSTER_INDEX')
count=$CLUSTER_SIZE
fqdns='$CLUSTER_FQDNS'.split(',')
localips='$CLUSTER_LOCAL_IPS'.split(',')
floatingips='$CLUSTER_FLOATING_IPS'.split(',')
with open('/etc/hosts', 'a') as f:
  f.write("\n")
  for index in range(0, count):
    hn=fqdns[index][0: fqdns[index].index('.')]
    f.write("{ip} {fqdn} {hn}\n".format(ip=localips[index],hn=hn,fqdn=fqdns[index]))

def pxc(f, m):
  a = "<?xml version='1.0' encoding='UTF-8'?>\n<?xml-stylesheet type='text/xsl' href='configuration.xsl'?>\n<configuration>"
  for n in m.keys():
    a = a + "\n  <property>\n    <name>{n}</name>\n    <value>{v}</value>\n  </property>".format(n=n,v=m[n])
  a = a + "\n</configuration>\n"
  with open(f, 'w') as xml:
    xml.write(a)
pxc('/etc/hadoop/conf/core-site.xml', {
  'fs.defaultFS':'hdfs://cl'
  })
pxc('/etc/hadoop/conf/hdfs-site.xml', {
  'dfs.namenode.datanode.registration.ip-hostname-check':'false',
  'dfs.namenode.name.dir':'/hadoop/hdfs/namenode',
  'dfs.hosts.exclude':'/etc/hadoop/conf/dfs.exclude',
  'dfs.datanode.data.dir':'/hadoop/hdfs/data',
  'dfs.journalnode.edits.dir':'/hadoop/hdfs/journalnode',
  'dfs.nameservices':'cl',
  'dfs.ha.namenodes.cl':'nn1,nn2',
  'dfs.namenode.rpc-address.cl.nn1':localips[0]+':8020',
  'dfs.namenode.rpc-address.cl.nn2':localips[1]+':8020',
  'dfs.namenode.http-address.cl.nn1':localips[0]+':50070',
  'dfs.namenode.http-address.cl.nn2':localips[1]+':50070',
  'dfs.namenode.shared.edits.dir':'qjournal://'+localips[0]+':8485;'+localips[1]+':8485;'+localips[2]+':8485/cl',
  'dfs.journalnode.edits.dir':'/hadoop/hdfs/journalnode',
  'dfs.client.failover.proxy.provider.cl':'org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider',
  'dfs.ha.fencing.methods':'sshfence(hdfs),shell(/bin/true)',
  'dfs.ha.fencing.ssh.private-key-files':'/var/lib/hadoop-hdfs/.ssh/id_rsa',
  'dfs.ha.fencing.ssh.connect-timeout':'30000',
  'dfs.ha.automatic-failover.enabled':'true',
  'ha.zookeeper.quorum':localips[0]+':2181,'+localips[1]+':2181,'+localips[2]+':2181'
  })
pxc('/etc/hadoop/conf/yarn-site.xml', {
  'yarn.nodemanager.vmem-check-enabled':'false',
  'yarn.application.classpath':'/etc/hadoop/conf,/usr/hdp/current/hadoop-client/*,/usr/hdp/current/hadoop-client/lib/*,/usr/hdp/current/hadoop-hdfs-client/*,/usr/hdp/current/hadoop-hdfs-client/lib/*,/usr/hdp/current/hadoop-yarn-client/*,/usr/hdp/current/hadoop-yarn-client/lib/*',
  'yarn.nodemanager.delete.debug-delay-sec':'43200',
  'yarn.scheduler.minimum-allocation-mb':'512',
  'yarn.scheduler.maximum-allocation-mb':'8192',
  'yarn.nodemanager.local-dirs':'/hadoop/yarn/local',
  'yarn.nodemanager.log-dirs':'/hadoop/yarn/log',
  'yarn.resourcemanager.zk-address':localips[0]+':2181,'+localips[1]+':2181,'+localips[2]+':2181',
  'yarn.resourcemanager.ha.enabled':'true',
  'yarn.resourcemanager.ha.rm-ids':'rm1,rm2',
  'yarn.resourcemanager.hostname.rm1':localips[1],
  'yarn.resourcemanager.hostname.rm2':localips[2],
  'yarn.resourcemanager.cluster-id':'cl',
  'yarn.resourcemanager.recovery-enabled':'true',
  'yarn.resourcemanager.store.class':'org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore',
  'yarn.resourcemanager.nodes.exclude-path':'/etc/hadoop/conf/yarn.exclude'
  })
pxc('/etc/hadoop/conf/mapred-site.xml', {
  'mapreduce.application.classpath':'/etc/hadoop/conf,/usr/lib/hadoop/lib/*,/usr/lib/hadoop/*,/usr/hdp/current/hadoop-hdfs-namenode/,/usr/hdp/current/hadoop-hdfs-namenode/lib/*,/usr/hdp/current/hadoop-hdfs-namenode/*,/usr/hdp/current/hadoop-yarn-nodemanager/lib/*,/usr/hdp/current/hadoop-yarn-nodemanager/*,/usr/hdp/current/hadoop-mapreduce-historyserver/lib/*,/usr/hdp/current/hadoop-mapreduce-historyserver/*',
  'mapreduce.jobhistory.intermediate-done-dir':'/mr-history/tmp',
  'mapreduce.jobhistory.done-dir':'/mr-history/done',
  'mapreduce.jobhistory.address':localips[1],
  'mapreduce.jobhistory.webapp.address':localips[1]
  })
pxc('/etc/hbase/conf/hbase-site.xml', {
  'hbase.zookeeper.quorum':localips[0]+':2181,'+localips[1]+':2181,'+localips[2]+':2181',
  'hbase.rootdir':'hdfs://cl/apps/hbase/data',
  'hbase.cluster.distributed':'true'
  })
pxc('/etc/hive/conf/hive-site.xml', {
  'fs.file.impl.disable.cache':'true',
  'fs.hdfs.impl.disable.cache':'true',
  'hadoop.clientside.fs.operations':'true',
  'hive.auto.convert.join.noconditionaltask.size':'1000000000',
  'hive.auto.convert.sortmerge.join.noconditionaltask':'true',
  'hive.auto.convert.sortmerge.join':'true',
  'hive.enforce.bucketing':'true',
  'hive.enforce.sorting':'true',
  'hive.mapjoin.bucket.cache.size':'10000',
  'hive.mapred.reduce.tasks.speculative.execution':'false',
  'hive.metastore.cache.pinobjtypes':'Table,Database,Type,FieldSchema,Order',
  'hive.metastore.client.socket.timeout':'60s',
  'hive.metastore.local':'true',
  'hive.metastore.uris':'thrift://' + fqdns[2] + ':9083',
  'hive.metastore.warehouse.dir':'/apps/hive/warehouse',
  'hive.optimize.bucketmapjoin.sortedmerge':'true',
  'hive.optimize.bucketmapjoin':'true',
  'hive.optimize.mapjoin.mapreduce':'true',
  'hive.optimize.reducededuplication.min.reducer':'1',
  'hive.security.authorization.manager':'org.apache.hadoop.hive.ql.security.authorization.DefaultHiveAuthorizationProvider',
  'hive.semantic.analyzer.factory.impl':'org.apache.hivealog.cli.HCatSemanticAnalyzerFactory',
  'javax.jdo.option.ConnectionDriverName':'com.mysql.jdbc.Driver',
  'javax.jdo.option.ConnectionPassword': mysqlpw,
  'javax.jdo.option.ConnectionURL':'jdbc:mysql://localhost:3306/metastore?createDatabaseIfNotExist=true',
  'javax.jdo.option.ConnectionUserName':'root'
  })
if myid == 2:
  pxc('/etc/cdap/conf/cdap-site.xml', {
    'zookeeper.quorum':localips[0]+':2181,'+localips[1]+':2181,'+localips[2]+':2181/\${root.namespace}',
    'router.server.address':localips[2],
    'explore.enabled':'true',
    'enable.unrecoverable.reset':'true',
    'kafka.seed.brokers':localips[2] + ':9092',
    'app.program.jvm.opts':'-XX:MaxPermSize=128M \${twill.jvm.gc.opts} -Dhdp.version=$HDPVER -Dspark.yarn.am.extraJavaOptions=-Dhdp.version=$HDPVER'
    })
with open('/etc/hbase/conf/regionservers', 'w') as f:
  for ip in localips:
    f.write('{ip}\n'.format(ip=ip))
with open('/etc/hbase/conf/hbase-env.sh', 'a') as f:
  f.write("export HBASE_MANAGES_ZK=false\n")
with open('/etc/zookeeper/conf/zoo.cfg', 'a') as f:
  f.write("server.1={L1}:2888:3888\nserver.2={L2}:2888:3888\nserver.3={L3}:2888:3888\nmaxClientCnxns=0\nautopurge.purgeInterval=6\n".format(L1=localips[0],L2=localips[1],L3=localips[2]))
with open('/etc/clustermembers', 'w') as f:
  f.write("export me={me}\n".format(me=myid))
  for idx in range(len(localips)):
    f.write("export n{i}={ip}\n".format(i=idx, ip=localips[idx]))
    f.write("export N{i}={ip}\n".format(i=idx, ip=floatingips[idx]))
with open('/etc/hadoop/conf/slaves', 'w') as f:
  for idx in range(len(localips)):
    if idx != myid:
      f.write("{x}\n".format(x=localips[idx]))
if myid < 3:
  with open('/var/lib/zookeeper/myid', 'w') as f:
    f.write("{id}".format(id=(myid + 1)))
  os.system('service zookeeper-server restart')
for ip in localips:
  os.system("su - hdfs -c \"ssh -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=0 {ip} echo Connectivity to {ip} verified\"".format(ip=ip))
!EOF

python /tmp/init.py

. /etc/clustermembers
waitfor() {
	while ( ! nc $1 $2 </dev/null )
	do
		echo waiting for $1 port $2
		sleep 30
	done
}
# journal nodes are on port 8485
if [ $me -lt 3 ]
then
	su - hdfs -c '$HADOOP_HOME/sbin/hadoop-daemon.sh start journalnode'
	waitfor $n0 8485
	waitfor $n1 8485
	waitfor $n2 8485
fi
if [ $me -eq 0 -a "$setupdone" = "" ]
then
	su - hdfs -c 'hdfs namenode -format -nonInteractive'
	su - hdfs -c 'hdfs zkfc -formatZK'
fi
if [ $me -eq 1 -a "$setupdone" = "" ]
then
	waitfor $n0 8020
	su - hdfs -c 'hdfs namenode -bootstrapStandby -nonInteractive'
	su - yarn -c 'yarn resourcemanager -format-state-store'
fi
if [ $me -eq 0 -o $me -eq 1 ]
then
	su - hdfs -c '$HADOOP_HOME/sbin/hadoop-daemon.sh start zkfc'
	su - hdfs -c '$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode'
fi
su - hdfs -c '$HADOOP_HOME/sbin/hadoop-daemon.sh start datanode'
if [ $me -eq 1 -o $me -eq 2 ]
then
	su - yarn -c '/usr/hdp/current/hadoop-yarn-nodemanager/sbin/yarn-daemon.sh start resourcemanager'
fi
su - yarn -c '/usr/hdp/current/hadoop-yarn-nodemanager/sbin/yarn-daemon.sh start nodemanager'
waitfor $n0 8020
waitfor $n1 8020
su - hdfs -c 'hdfs dfsadmin -safemode wait'
if [ $me -eq 1 ]
then
	if [ "$setupdone" = "" ]
	then
		su - hdfs -c 'hdfs dfs -mkdir -p /mr-history/tmp'
		su - hdfs -c 'hdfs dfs -chmod -R 1777 /mr-history/tmp'
		su - hdfs -c 'hdfs dfs -mkdir -p /mr-history/done'
		su - hdfs -c 'hdfs dfs -chmod -R 1777 /mr-history/done'
		su - hdfs -c 'hdfs dfs -chown -R mapred:hdfs /mr-history'
		su - hdfs -c 'hdfs dfs -mkdir -p /app-logs'
		su - hdfs -c 'hdfs dfs -chmod -R 1777 /app-logs'
		su - hdfs -c 'hdfs dfs -chown yarn:hdfs  /app-logs'
		su - hdfs -c 'hdfs dfs -mkdir -p /apps/hbase/staging /apps/hbase/data'
		su - hdfs -c 'hdfs dfs -chown hbase:hdfs /apps/hbase/staging /apps/hbase/data'
		su - hdfs -c 'hdfs dfs -chmod 711 /apps/hbase/staging'
		su - hdfs -c 'hdfs dfs -chmod 755 /apps/hbase/data'
		su - hdfs -c 'hdfs dfs -chown hdfs:hdfs /apps/hbase'
		su - hdfs -c 'hdfs dfs -mkdir -p /user/yarn'
		su - hdfs -c 'hdfs dfs -chown yarn:yarn /user/yarn'
		su - hdfs -c 'hdfs dfs -mkdir -p /cdap/tx.snapshot'
		su - hdfs -c 'hdfs dfs -chown yarn:yarn /cdap /cdap/tx.snapshot'
		su - hdfs -c 'hdfs dfs -mkdir -p /user/hive /apps/hive/warehouse /tmp/hive'
		su - hdfs -c 'hdfs dfs -chown -R hive:hadoop /user/hive /apps/hive /tmp/hive'
		su - hdfs -c 'hdfs dfs -chmod -R 775 /apps/hive'
		su - hdfs -c 'hdfs dfs -chmod -R 777 /tmp/hive'
	fi
	su - mapred -c '/usr/hdp/current/hadoop-mapreduce-historyserver/sbin/mr-jobhistory-daemon.sh start historyserver'
	su - hbase -c '/usr/hdp/current/hbase-master/bin/hbase-daemon.sh start master'
fi
while [ "" != "$( echo get /hbase/master | hbase zkcli 2>&1 | grep 'Node does not exist: /hbase/master')" ]
do
	echo Waiting for hbase master to come up
	sleep 30
done
su - hbase -c '/usr/hdp/current/hbase-regionserver/bin/hbase-daemon.sh start regionserver'

if [ $me -eq 2 ]
then
	if [ "$setupdone" = "" ]
	then
		su - hive -c '/usr/hdp/current/hive-metastore/bin/schematool -initSchema -dbType mysql'
	fi
	su - hive -c 'nohup /usr/hdp/current/hive-metastore/bin/hive --service metastore >>/var/log/hive/hive.out 2>>/var/log/hive/hive.log </dev/null &'
	(cd /bin; wget https://raw.githubusercontent.com/caskdata/cdap-monitoring-tools/develop/nagios/check_cdap/bin/check_cdap)
	chmod 755 /bin/check_cdap
	wget -qO- $CODE_SOURCE/${CODE_VERSION}/cloud_init/instconsulagentub16.sh >/tmp/cinst.sh
	bash /tmp/cinst.sh <<!EOF
{
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "advertise_addr": "$n2",
  "data_dir": "/opt/consul/data",
  "datacenter": "$DATACENTER",
  "http_api_response_headers": {
    "Access-Control-Allow-Origin": "*"
  },
  "rejoin_after_leave": true,
  "server": false,
  "ui": false,
  "enable_syslog": true,
  "log_level": "info",
  "service": {
    "id": "$REGISTERED_NAME",
    "name": "$REGISTERED_NAME",
    "address": "$N2",
    "port": 11015,
    "checks": [
      {
        "script": "/bin/check_cdap",
        "interval": "60s"
      }
    ]
  }
}
!EOF
	for i in $(cd /etc/init.d; echo *cdap*)
	do
		service $i start
	done
fi

if [ "$setupdone" = "" ]
then
	echo setupdone=true >>/etc/clustermembers
fi
