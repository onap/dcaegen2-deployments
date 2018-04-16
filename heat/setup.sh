#!/bin/bash


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

echo "Launching Cloudify Manager"
docker run -d \
--network="${NETWORK}" \
--name cloudify-manager \
--restart unless-stopped \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-p 80:80 \
--tmpfs /run \
--tmpfs /run/lock \
--security-opt seccomp:unconfined \
--cap-add SYS_ADMIN \
--label "SERVICE_80_NAME=cloudify_manager" \
--label "SERVICE_80_CHECK_TCP=true" \
--label "SERVICE_80_CHECK_INTERVAL=15s" \
--label "SERVICE_80_CHECK_INITIAL_STATUS=passing" \
{{i nexus_docker_repo }}/onap/org.onap.dcaegen2.deployments.cm-container:{{ dcae_docker_cm }}
echo "Cloudify Manager deployed, waiting for completion" 
while ! nc -z localhost 80; do sleep 1; done

echo "configure Cloudify Manager"
#8080, 5432 ports occupied
pip install cloudify==4.2
cfy profiles use 127.0.0.1 -u admin -p admin -t default_tenant
cfy status

./build-plugins.sh https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.plugins/R2 https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/plugins/releases

for wagon in ./wagons/*.wgn; do     cfy plugins upload ${wagon}; done

echo "Setup complete"
