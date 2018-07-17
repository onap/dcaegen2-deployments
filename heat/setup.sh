#!/bin/bash
#############################################################################
#
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#############################################################################


NETWORK="config_default"

echo "Cleaning up any previously deployed cludify manager and registrator"
docker stop registrator cloudify-manager
docker rm registrator cloudify-manager

echo "Launching registrator on dockerhost"
docker run -d \
--network=${NETWORK} \
--name=registrator \
-e EXTERNAL_IP={{ dcae_ip_addr }} \
-e CONSUL_HOST=consul \
-v /var/run/docker.sock:/tmp/docker.sock \
onapdcae/registrator:v7




rm -rf scripts-in-container
mkdir scripts-in-container
cat > scripts-in-container/install-plugins.sh << EOL
#!/bin/bash
source /cfy42/bin/activate
pip install pip==9.0.3
cfy profiles use 127.0.0.1 -u admin -p admin -t default_tenant
cfy status
cd /tmp/bin
./build-plugins.sh https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.plugins/R3 https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/releases
for wagon in ./wagons/*.wgn; do cfy plugins upload \$wagon ; done
deactivate
EOL

wget -O scripts-in-container/build-plugins.sh https://git.onap.org/dcaegen2/deployments/plain/k8s-bootstrap-container/build-plugins.sh
chmod 777 scripts-in-container/*

echo "Launching Cloudify Manager container"
docker run -d \
--network="${NETWORK}" \
--name cloudify-manager \
--restart unless-stopped \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-v /opt/app/config/scripts-in-container:/tmp/bin \
-p 80:80 \
--tmpfs /run \
--tmpfs /run/lock \
--security-opt seccomp:unconfined \
--cap-add SYS_ADMIN \
--label "SERVICE_80_NAME=cloudify_manager" \
--label "SERVICE_80_CHECK_TCP=true" \
--label "SERVICE_80_CHECK_INTERVAL=15s" \
--label "SERVICE_80_CHECK_INITIAL_STATUS=passing" \
{{ nexus_docker_repo }}/onap/org.onap.dcaegen2.deployments.cm-container:{{ dcae_docker_cm }}

echo "Cloudify Manager deployed, waiting for completion"
while ! nc -z localhost 80; do sleep 1; done

echo "Upload plugins to Cloudify Manager"

# run as detached because this script is intended to be run in background
docker exec -itd cloudify-manager /tmp/bin/install-plugins.sh

echo "Cloudify Manager setup complete"

