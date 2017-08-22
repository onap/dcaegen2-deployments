#!/bin/bash
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

CONSULVER=consul_0.8.3
CONSULNAME=${CONSULVER}_linux_amd64
CB=/opt/consul/bin
CD=/opt/consul/data
CF=/opt/consul/config
mkdir -p $CB $CD $CF
cat >$CF/consul.json
cd $CB
wget https://releases.hashicorp.com/consul/${CONSULVER}/${CONSULNAME}.zip
unzip ${CONSULNAME}.zip
rm ${CONSULNAME}.zip
mv consul ${CONSULNAME}
ln -s ${CONSULNAME} consul
cat <<EOF > /lib/systemd/system/consul.service
[Unit]
Description=Consul
Requires=network-online.target
After=network.target
[Service]
Type=simple
ExecStart=/opt/consul/bin/consul agent -config-dir=/opt/consul/config
ExecReload=/bin/kill -HUP \$MAINPID
[Install]
WantedBy=multi-user.target
EOF
systemctl enable consul
systemctl start consul     
until /opt/consul/bin/consul join "dcae-cnsl"
do
  echo Waiting to join Consul cluster
  sleep 60
done
