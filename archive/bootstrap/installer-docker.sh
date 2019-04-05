#!/bin/bash
#
# ============LICENSE_START==========================================
# ===================================================================
# Copyright © 2017-2018 AT&T Intellectual Property. All rights reserved.
# ===================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END============================================
#

# URLs for artifacts needed for installation
DESIGTYPES=https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/releases/type_files/dnsdesig/dns_types.yaml
DESIGPLUG=https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/releases/plugins/dnsdesig-1.0.0-py27-none-any.wgn
SSHKEYTYPES=https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/releases/type_files/sshkeyshare/sshkey_types.yaml
SSHKEYPLUG=https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/releases/plugins/sshkeyshare-1.0.0-py27-none-any.wgn
OSPLUGINZIP=https://github.com/cloudify-cosmo/cloudify-openstack-plugin/archive/1.4.zip
OSPLUGINWGN=https://github.com/cloudify-cosmo/cloudify-openstack-plugin/releases/download/2.2.0/cloudify_openstack_plugin-2.2.0-py27-none-linux_x86_64-centos-Core.wgn

PLATBPSRC=https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.blueprints/releases/blueprints
DOCKERBP=DockerBP.yaml
CBSBP=config_binding_service.yaml
PGBP=pgaas-onevm.yaml
CDAPBP=cdapbp7.yaml
CDAPBROKERBP=cdap_broker.yaml
INVBP=inventory.yaml
DHBP=DeploymentHandler.yaml
PHBP=policy_handler.yaml
VESBP=ves.yaml
TCABP=tca.yaml
HRULESBP=holmes-rules.yaml
HENGINEBP=holmes-engine.yaml
PRHBP=prh.yaml
HVVESBP=hv-ves.yaml

DOCKERBPURL="${PLATBPSRC}/${DOCKERBP}"
CBSBPURL="${PLATBPSRC}/${CBSBP}"
PGBPURL="${PLATBPSRC}/${PGBP}"
CDAPBPURL="${PLATBPSRC}/${CDAPBP}"
CDAPBROKERBPURL="${PLATBPSRC}/${CDAPBROKERBP}"
INVBPURL="${PLATBPSRC}/${INVBP}"
DHBPURL="${PLATBPSRC}/${DHBP}"
PHBPURL="${PLATBPSRC}/${PHBP}"
VESBPURL="${PLATBPSRC}/${VESBP}"
TCABPURL="${PLATBPSRC}/${TCABP}"
HRULESBPURL="${PLATBPSRC}/${HRULESBP}"
HENGINEBPURL="${PLATBPSRC}/${HENGINEBP}"
PRHBPURL="${PLATBPSRC}/${PRHBP}"
HVVESBPURL="${PLATBPSRC}/${HVVESBP}"

LOCATIONID=$(printenv LOCATION)

# Make sure ssh doesn't prompt for new host or choke on a new host with an IP it's seen before
SSHOPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
STARTDIR=$(pwd)

# clear out files for writing out floating IP addresses
rm -f "$STARTDIR"/config/runtime.ip.consul
rm -f "$STARTDIR"/config/runtime.ip.cm


SSHUSER=centos
PVTKEY=./config/key
INPUTS=./config/inputs.yaml

if [ "$LOCATION" = "" ]
then
	echo 'Environment variable LOCATION not set.  Should be set to location ID for this installation.'
	exit 1
fi

set -e
set -x

# Docker workaround for SSH key
# In order for the container to be able to access the key when it's mounted from the Docker host,
# the key file has to be world-readable.   But ssh itself will not work with a private key that's world readable.
# So we make a copy and change permissions on the copy.
# NB -- the key on the Docker host has to be world-readable, which means that, from the host machine, you
# can't use it with ssh.  It needs to be a world-readable COPY.
PVTKEY=./key600
cp ./config/key ${PVTKEY}
chmod 600 ${PVTKEY}

# Create a virtual environment
virtualenv dcaeinstall
source dcaeinstall/bin/activate

# forcing pip version (pip>=10.0.0 no longer support use wheel)
pip install pip==9.0.3 

# Install Cloudify
pip install cloudify==3.4.0

# Install the Cloudify OpenStack plugin 
wget -qO- ${OSPLUGINZIP} > openstack.zip
pip install openstack.zip

# Spin up a VM

# Get the Designate and SSH key type files and plugins
mkdir types
wget -qO- ${DESIGTYPES} > types/dns_types.yaml
wget -qO- ${SSHKEYTYPES} > types/sshkey_types.yaml

wget -O dnsdesig.wgn ${DESIGPLUG}
wget -O sshkeyshare.wgn ${SSHKEYPLUG}

wagon install -s dnsdesig.wgn
wagon install -s sshkeyshare.wgn

## Fix up the inputs file to get the private key locally
sed -e "s#key_filename:.*#key_filename: $PVTKEY#" < ${INPUTS} > /tmp/local_inputs

# Now install the VM
# Don't exit on error after this point--keep container running so we can do uninstalls after a failure
set +e
if wget -O /tmp/centos_vm.yaml "${PLATBPSRC}"/centos_vm.yaml; then
  mv -f /tmp/centos_vm.yaml ./blueprints/
  echo "Succeeded in getting the newest centos_vm.yaml"
else
  echo "Failed to update centos_vm.yaml, using default version"
  rm -f /tmp/centos_vm.yaml
fi
set -e
cfy local init --install-plugins -p ./blueprints/centos_vm.yaml -i /tmp/local_inputs -i "datacenter=$LOCATION"
cfy local execute -w install --task-retries=10
PUBIP=$(cfy local outputs | grep -Po '"public_ip": "\K.*?(?=")')

# wait till the cloudify manager's sshd ready
while ! nc -z -v -w5 ${PUBIP} 22; do echo "."; done
sleep 10

echo "Installing Cloudify Manager on ${PUBIP}."
PVTIP=$(ssh $SSHOPTS -i "$PVTKEY" "$SSHUSER"@"$PUBIP" 'echo PVTIP=`curl --silent http://169.254.169.254/2009-04-04/meta-data/local-ipv4`' | grep PVTIP | sed 's/PVTIP=//')
if [ "$PVTIP" = "" ]
then
    echo Cannot access specified machine at $PUBIP using supplied credentials
    exit
fi


# Copy private key onto Cloudify Manager VM
PVTKEYPATH=$(cat ${INPUTS} | grep "key_filename" | cut -d "'" -f2)
PVTKEYNAME=$(basename $PVTKEYPATH)
PVTKEYDIR=$(dirname $PVTKEYPATH)
scp  $SSHOPTS -i $PVTKEY $PVTKEY $SSHUSER@$PUBIP:/tmp/$PVTKEYNAME
ssh -t $SSHOPTS -i $PVTKEY $SSHUSER@$PUBIP sudo mkdir -p $PVTKEYDIR
ssh -t  $SSHOPTS -i $PVTKEY $SSHUSER@$PUBIP sudo mv /tmp/$PVTKEYNAME $PVTKEYPATH

ESMAGIC=$(uuidgen -r)
WORKDIR=$HOME/cmtmp
BSDIR=$WORKDIR/cmbootstrap
PVTKEY2=$BSDIR/id_rsa.cfybootstrap
TMPBASE=$WORKDIR/tmp
TMPDIR=$TMPBASE/lib
SRCS=$WORKDIR/srcs.tar
TOOL=$WORKDIR/tool.py
rm -rf $WORKDIR
mkdir -p $BSDIR $TMPDIR/cloudify/wheels $TMPDIR/cloudify/sources $TMPDIR/manager
chmod 700 $WORKDIR
cp "$PVTKEY" $PVTKEY2
cat >$TOOL <<!EOF
#!/usr/local/bin/python
#
import yaml
import sys
bsdir = sys.argv[1]
with open(bsdir + '/simple-manager-blueprint-inputs.yaml', 'r') as f:
  inpyaml = yaml.load(f)
with open(bsdir + '/simple-manager-blueprint.yaml', 'r') as f:
  bpyaml = yaml.load(f)
for param, value in bpyaml['inputs'].items():
  if value.has_key('default') and not inpyaml.has_key(param):
    inpyaml[param] = value['default']
print inpyaml['manager_resources_package']
!EOF

#
#	Try to disable attempt to download virtualenv when not needed
#
ssh $SSHOPTS -t -i $PVTKEY2 $SSHUSER@$PUBIP 'sudo bash -xc "echo y; mkdir -p /root/.virtualenv; echo '"'"'[virtualenv]'"'"' >/root/.virtualenv/virtualenv.ini; echo no-download=true >>/root/.virtualenv/virtualenv.ini"'

# Gather installation artifacts
# from documentation, URL for manager blueprints archive
BSURL=https://github.com/cloudify-cosmo/cloudify-manager-blueprints/archive/3.4.tar.gz
BSFILE=$(basename $BSURL)

umask 022
wget -qO- $BSURL >$BSDIR/$BSFILE
cd $BSDIR
tar xzvf $BSFILE
MRPURL=$(python $TOOL $BSDIR/cloudify-manager-blueprints-3.4)
MRPFILE=$(basename $MRPURL)
wget -qO- $MRPURL >$TMPDIR/cloudify/sources/$MRPFILE

tar cf $SRCS -C $TMPDIR cloudify
rm -rf $TMPBASE
#
# Load required package files onto VM
#
scp $SSHOPTS -i $PVTKEY2 $SRCS $SSHUSER@$PUBIP:/tmp/.
ssh -t $SSHOPTS -i $PVTKEY2 $SSHUSER@$PUBIP 'sudo bash -xc "cd /opt; tar xf /tmp/srcs.tar; chown -R root:root /opt/cloudify /opt/manager; rm -rf /tmp/srcs.tar"'
#
#	Install config file -- was done by DCAE controller.  What now?
#
ssh $SSHOPTS -t -i $PVTKEY2 $SSHUSER@$PUBIP 'sudo bash -xc '"'"'mkdir -p /opt/dcae; if [ -f /tmp/cfy-config.txt ]; then cp /tmp/cfy-config.txt /opt/dcae/config.txt && chmod 644 /opt/dcae/config.txt; fi'"'"
cd $WORKDIR

#
#	Check for and set up https certificate information
#
rm -f $BSDIR/cloudify-manager-blueprints-3.4/resources/ssl/server.key $BSDIR/cloudify-manager-blueprints-3.4/resources/ssl/server.crt
ssh -t $SSHOPTS -i $PVTKEY2 $SSHUSER@$PUBIP 'sudo bash -xc "openssl pkcs12 -in /opt/app/dcae-certificate/certificate.pkcs12 -passin file:/opt/app/dcae-certificate/.password -nodes -chain"' | awk 'BEGIN{x="/dev/null";}/-----BEGIN CERTIFICATE-----/{x="'$BSDIR'/cloudify-manager-blueprints-3.4/resources/ssl/server.crt";}/-----BEGIN PRIVATE KEY-----/{x="'$BSDIR'/cloudify-manager-blueprints-3.4/resources/ssl/server.key";}{print >x;}/-----END /{x="/dev/null";}'
USESSL=false
if [ -f $BSDIR/cloudify-manager-blueprints-3.4/resources/ssl/server.key -a -f $BSDIR/cloudify-manager-blueprints-3.4/resources/ssl/server.crt ]
then
	USESSL=true
fi
#
#	Set up configuration for the bootstrap
#
export CLOUDIFY_USERNAME=admin CLOUDIFY_PASSWORD=encc0fba9f6d618a1a51935b42342b17658
cd $BSDIR/cloudify-manager-blueprints-3.4
cp simple-manager-blueprint.yaml bootstrap-blueprint.yaml
ed bootstrap-blueprint.yaml <<'!EOF'
/^node_types:/-1a
  plugin_resources:
    description: >
      Holds any archives that should be uploaded to the manager.
    default: []
  dsl_resources:
    description: >
      Holds a set of dsl required resources
    default: []
.
/^        upload_resources:/a
          plugin_resources: { get_input: plugin_resources }
.
w
q
!EOF

sed <simple-manager-blueprint-inputs.yaml >bootstrap-inputs.yaml \
	-e "s;.*public_ip: .*;public_ip: '$PUBIP';" \
	-e "s;.*private_ip: .*;private_ip: '$PVTIP';" \
	-e "s;.*ssh_user: .*;ssh_user: '$SSHUSER';" \
	-e "s;.*ssh_key_filename: .*;ssh_key_filename: '$PVTKEY2';" \
	-e "s;.*elasticsearch_java_opts: .*;elasticsearch_java_opts: '-Des.cluster.name=$ESMAGIC';" \
	-e "/ssl_enabled: /s/.*/ssl_enabled: $USESSL/" \
	-e "/security_enabled: /s/.*/security_enabled: $USESSL/" \
	-e "/admin_password: /s/.*/admin_password: '$CLOUDIFY_PASSWORD'/" \
	-e "/admin_username: /s/.*/admin_username: '$CLOUDIFY_USERNAME'/" \
	-e "s;.*manager_resources_package: .*;manager_resources_package: 'http://169.254.169.254/nosuchthing/$MRPFILE';" \
	-e "s;.*ignore_bootstrap_validations: .*;ignore_bootstrap_validations: true;" \

# Add plugin resources
# TODO Maintain plugin list as updates/additions occur
cat >>bootstrap-inputs.yaml <<'!EOF'
plugin_resources:
  - 'http://repository.cloudifysource.org/org/cloudify3/wagons/cloudify-openstack-plugin/1.4/cloudify_openstack_plugin-1.4-py27-none-linux_x86_64-centos-Core.wgn'
  - 'http://repository.cloudifysource.org/org/cloudify3/wagons/cloudify-fabric-plugin/1.4.1/cloudify_fabric_plugin-1.4.1-py27-none-linux_x86_64-centos-Core.wgn'
  - 'https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/releases/plugins/dnsdesig-1.0.0-py27-none-any.wgn'
  - 'https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/releases/plugins/sshkeyshare-1.0.0-py27-none-any.wgn'
  - 'https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins/releases/plugins/pgaas-1.0.0-py27-none-any.wgn'
  - 'https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.plugins/releases/plugins/cdapcloudify/cdapcloudify-14.2.5-py27-none-any.wgn'
  - 'https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.plugins/releases/plugins/dcaepolicyplugin/dcaepolicyplugin-1.0.0-py27-none-any.wgn'
  - 'https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.plugins/releases/plugins/dockerplugin/dockerplugin-2.4.0-py27-none-any.wgn'
  - 'https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.plugins/releases/plugins/relationshipplugin/relationshipplugin-1.0.0-py27-none-any.wgn'
!EOF
#
#	And away we go
#
cfy init -r
cfy bootstrap --install-plugins -p bootstrap-blueprint.yaml -i bootstrap-inputs.yaml
rm -f resources/ssl/server.key

# Install Consul VM via a blueprint
cd $STARTDIR
mkdir consul
cd consul
cfy init -r
cfy use -t ${PUBIP}
echo "Deploying Consul VM"

set +e
if wget -O /tmp/consul_cluster.yaml "${PLATBPSRC}"/consul_cluster.yaml; then
  mv -f /tmp/consul_cluster.yaml ../blueprints/
  echo "Succeeded in getting the newest consul_cluster.yaml"
else
  echo "Failed to update consul_cluster.yaml, using default version"
  rm -f /tmp/consul_cluster.yaml
fi
set -e
cfy install -p ../blueprints/consul_cluster.yaml -d consul -i ../${INPUTS} -i "datacenter=$LOCATION"

# Get the floating IP for one member of the cluster
# Needed for instructing the Consul agent on CM host to join the cluster
CONSULIP=$(cfy deployments outputs -d consul | grep -Po 'Value: \K.*')
echo Consul deployed at $CONSULIP

# Wait for Consul API to come up
until curl http://$CONSULIP:8500/v1/agent/services
do
   echo Waiting for Consul API
   sleep 60
done

# Wait for a leader to be elected
until [[ "$(curl -Ss http://$CONSULIP:8500/v1/status/leader)" != '""' ]]
do
	echo Waiting for leader
	sleep 30
done

# Instruct the client-mode Consul agent running on the CM to join the cluster
curl http://$PUBIP:8500/v1/agent/join/$CONSULIP

# Register Cloudify Manager in Consul via the local agent on CM host

REGREQ="
{
  \"Name\" : \"cloudify_manager\",
  \"ID\" : \"cloudify_manager\",
  \"Tags\" : [\"http://${PUBIP}/api/v2.1\"],
  \"Address\": \"${PUBIP}\",
  \"Port\": 80,
  \"Check\" : {
    \"Name\" : \"cloudify_manager_health\",
    \"Interval\" : \"300s\",
    \"HTTP\" : \"http://${PUBIP}/api/v2.1/status\",
    \"Status\" : \"passing\",
    \"DeregisterCriticalServiceAfter\" : \"30m\"
  }
}
"

curl -X PUT -H 'Content-Type: application/json' --data-binary "$REGREQ" http://$PUBIP:8500/v1/agent/service/register
# Make Consul address available to plugins on Cloudify Manager
# TODO probably not necessary anymore
ENVINI=$(mktemp)
cat <<!EOF > $ENVINI
[$LOCATION]
CONSUL_HOST=$CONSULIP
CONFIG_BINDING_SERVICE=config_binding_service
!EOF
scp $SSHOPTS -i ../$PVTKEY $ENVINI $SSHUSER@$PUBIP:/tmp/env.ini
ssh -t $SSHOPTS -i ../$PVTKEY $SSHUSER@$PUBIP sudo mv /tmp/env.ini /opt/env.ini
rm $ENVINI


##### INSTALLATION OF PLATFORM COMPONENTS

# Get component blueprints
wget -P ./blueprints/docker/ ${DOCKERBPURL}
wget -P ./blueprints/cbs/ ${CBSBPURL}
wget -P ./blueprints/pg/ ${PGBPURL}
wget -P ./blueprints/cdap/ ${CDAPBPURL}
wget -P ./blueprints/cdapbroker/ ${CDAPBROKERBPURL}
wget -P ./blueprints/inv/ ${INVBPURL}
wget -P ./blueprints/dh/ ${DHBPURL}
wget -P ./blueprints/ph/ ${PHBPURL}
wget -P ./blueprints/ves/ ${VESBPURL}
wget -P ./blueprints/tca/ ${TCABPURL}
wget -P ./blueprints/hrules/ ${HRULESBPURL}
wget -P ./blueprints/hengine/ ${HENGINEBPURL}
wget -P ./blueprints/prh/ ${PRHBPURL}
wget -P ./blueprints/hv-ves/ ${HVVESBPURL}


# Set up the credentials for access to the Docker registry
curl -X PUT -H "Content-Type: application/json" --data-binary '[{"username":"docker", "password":"docker", "registry": "nexus3.onap.org:10001"}]'  http://${CONSULIP}:8500/v1/kv/docker_plugin/docker_logins

# Install platform Docker host
# Note we're still in the "consul" directory, which is init'ed for talking to CM

set +e 
# Docker host for platform containers
cfy install -v -p ./blueprints/docker/${DOCKERBP} -b DockerBP -d DockerPlatform -i ../${INPUTS} -i "registered_dockerhost_name=platform_dockerhost" -i "registrator_image=onapdcae/registrator:v7" -i "location_id=${LOCATION}" -i "node_name=dokp00" -i "target_datacenter=${LOCATION}"

# Docker host for service containers
cfy deployments create -b DockerBP -d DockerComponent -i ../${INPUTS} -i "registered_dockerhost_name=component_dockerhost" -i "location_id=${LOCATION}" -i "registrator_image=onapdcae/registrator:v7" -i "node_name=doks00" -i "target_datacenter=${LOCATION}"
cfy executions start -d DockerComponent -w install

# wait for the extended platform VMs settle
#sleep 180


# CDAP cluster
cfy install -p ./blueprints/cdap/${CDAPBP} -b cdapbp7 -d cdap7 -i ../config/cdapinputs.yaml -i "location_id=${LOCATION}"

# config binding service
cfy install -p ./blueprints/cbs/${CBSBP} -b config_binding_service -d config_binding_service -i "location_id=${LOCATION}"


# Postgres
cfy install -p ./blueprints/pg/${PGBP} -b pgaas -d pgaas  -i ../${INPUTS}


# Inventory
cfy install -p ./blueprints/inv/${INVBP} -b PlatformServicesInventory -d PlatformServicesInventory -i "location_id=${LOCATION}" -i ../config/invinputs.yaml


# Deployment Handler DH
cat >../dhinputs <<EOL
application_config:
  cloudify:
    protocol: "http"
  inventory:
    protocol: "http"
EOL
cfy install -p ./blueprints/dh/${DHBP} -b DeploymentHandlerBP -d DeploymentHandler -i "location_id=${LOCATION}"  -i ../dhinputs


# Policy Handler PH
cfy install -p ./blueprints/ph/${PHBP} -b policy_handler_BP -d policy_handler -i 'policy_handler_image=nexus3.onap.org:10001/onap/org.onap.dcaegen2.platform.policy-handler:1.1-latest' -i "location_id=${LOCATION}" -i ../config/phinputs.yaml


# Wait for the CDAP cluster to be registered in Consul
echo "Waiting for CDAP cluster to register"
until curl -Ss http://${CONSULIP}:8500/v1/catalog/service/cdap | grep cdap
do 
    echo -n .
    sleep 30
done
echo "CDAP cluster registered"


# CDAP Broker
cfy install -p ./blueprints/cdapbroker/${CDAPBROKERBP} -b cdapbroker -d cdapbroker -i "location_id=${LOCATION}"


# VES
cfy install -p ./blueprints/ves/${VESBP} -b ves -d ves -i ../config/vesinput.yaml


# TCA
cfy install -p ./blueprints/tca/${TCABP} -b tca -d tca -i ../config/tcainputs.yaml

# Holmes
cfy install -p ./blueprints/hrules/${HRULESBP} -b hrules -d hrules -i ../config/hr-ip.yaml
cfy install -p ./blueprints/hengine/${HENGINEBP} -b hengine -d hengine -i ../config/he-ip.yaml

# PRH
cfy install -p ./blueprints/prh/${PRHBP} -b prh -d prh -i ../config/prhinput.yaml

# HV-VES
cfy install -p ./blueprints/hv-ves/${HVVESBP} -b hv-ves -d hv-ves


# write out IP addresses
echo "$CONSULIP" > "$STARTDIR"/config/runtime.ip.consul
echo "$PUBIP" > "$STARTDIR"/config/runtime.ip.cm


# Keep the container up
rm -f /tmp/ready_to_exit
while [ ! -e /tmp/ready_to_exit ]
do
    sleep 30
done
