#!/bin/bash
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
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
#
# ECOMP is a trademark and service mark of AT&T Intellectual Property.

# Pull type files from repos
# Set up the CM import resolver
# $1 is the repo URL
#
set -x
DEST=/opt/manager/resources/onapspec
ONAPTYPEFILES=\
"\
/dcaepolicyplugin/2.0.0/dcaepolicyplugin_types.yaml \
/relationshipplugin/1.0.0/relationshipplugin_types.yaml \
/k8splugin/1.0.0/k8splugin_types.yaml \

"
mkdir ${DEST}
for typefile in ${ONAPTYPEFILES}
do
	mkdir -p ${DEST}/$(dirname ${typefile})
	curl -Ss $1/${typefile} >> ${DEST}/${typefile}
done
chown cfyuser:cfyuser ${DEST}
# Add our local type file store to CM import resolver configuration
TYPE_RULE="{${TYPE_REPO}: file://${DEST}}"
# This sed re is 'brittle' but we can be sure the config.yaml file
# won't change as long as we do not change the source Docker image for CM
sed -i -e "s#      rules:#      rules:\n      - ${TYPE_RULE}#" /etc/cloudify/config.yaml
chown cfyuser:cfyuser /etc/cloudify/config.yaml
