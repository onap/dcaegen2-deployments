#!/bin/bash
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2018-2020 AT&T Intellectual Property. All rights reserved.
# ================================================================================
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
# ============LICENSE_END=========================================================

# Pull type files from repos
# Set up the CM import resolver
# $1 is the DCAE repo URL
# $2 is the CCSDK repo URL
#
set -x
DEST=/opt/manager/resources/onapspec
EXTRA_RULES=/opt/manager/extra-resolver-rules

DCAETYPEFILES=\
"\
/dcaepolicyplugin/2.4.0/dcaepolicyplugin_types.yaml \
/relationshipplugin/1.1.0/relationshipplugin_types.yaml \
/k8splugin/1.7.2/k8splugin_types.yaml \
/k8splugin/2.0.0/k8splugin_types.yaml \
clamppolicyplugin/1.1.0/clamppolicyplugin_types.yaml \

"

CCSDKTYPEFILES=\
"\
/type_files/pgaas/1.1.0/pgaas_types.yaml \
/type_files/sshkeyshare/sshkey_types.yaml \
/type_files/helm/4.0.2/helm-type.yaml \
/type_files/dmaap/dmaap.yaml \
"

mkdir ${DEST}

for typefile in ${DCAETYPEFILES}
do
	mkdir -p ${DEST}/$(dirname ${typefile})
	curl -Ss -L -f $1/${typefile} >> ${DEST}/${typefile}
done

for typefile in ${CCSDKTYPEFILES}
do
	mkdir -p ${DEST}/$(dirname ${typefile})
	curl -Ss -L -f $2/${typefile} >> ${DEST}/${typefile}
done

chown cfyuser:cfyuser ${DEST}

# Add our local type file store to CM import resolver configuration
TYPE_RULE0="{\"$1\": \"file://${DEST}\"}"
TYPE_RULE1="{\"$2\": \"file://${DEST}\"}"
# This sed re is 'brittle' but we can be sure the config.yaml file
# won't change as long as we do not change the source Docker image for CM
sed -i -e "s#      rules:#      rules:\n      - ${TYPE_RULE0}#" /etc/cloudify/config.yaml
sed -i -e "s#      rules:#      rules:\n      - ${TYPE_RULE1}#" /etc/cloudify/config.yaml

chown cfyuser:cfyuser /etc/cloudify/config.yaml

# Changing /etc/cloudify/config.yaml is no longer sufficient
# Need to provide the additional rules in a file that can be
# used at deployment time to update the resolver rules
echo "- ${TYPE_RULE0}" > ${EXTRA_RULES}
echo "- ${TYPE_RULE1}" >> ${EXTRA_RULES}
