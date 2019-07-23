#!/bin/bash
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2018-2019 AT&T Intellectual Property. All rights reserved.
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

# Pull plugin archives from repos
# $1 is the DCAE repo URL
# $2 is the CCSDK repo URL
# (This script runs at Docker image build time)
#
set -x
DEST=wagons

# For DCAE, starting in R5, we pull down wagons directly
DCAEPLUGINFILES=\
"\
k8splugin/1.4.13/k8splugin-1.4.13-py27-none-linux_x86_64.wgn
k8splugin/1.6.0/k8splugin-1.6.0-py27-none-linux_x86_64.wgn
relationshipplugin/1.0.0/relationshipplugin-1.0.0-py27-none-any.wgn
clamppolicyplugin/1.0.0/clamppolicyplugin-1.0.0-py27-none-any.wgn
dcaepolicyplugin/2.3.0/dcaepolicyplugin-2.3.0-py27-none-any.wgn \
"

# For CCSDK, we pull down the wagon files directly
CCSDKPLUGINFILES=\
"\
plugins/pgaas-1.1.0-py27-none-any.wgn
plugins/dmaap-1.3.5-py27-none-any.wgn
plugins/sshkeyshare-1.0.0-py27-none-any.wgn
plugins/helm-4.0.0-py27-none-linux_x86_64.wgn
"

# Copy a set of wagons from a repo
# $1 -- repo baseURL
# $2 -- list of paths to wagons in the repo
function get_wagons {
	for wagon in $2
	do
		target=$(basename ${wagon})
		curl -Ss $1/${wagon} > ${DEST}/${target}
	done
}

mkdir ${DEST}
get_wagons $1 "${DCAEPLUGINFILES}"
get_wagons $2 "${CCSDKPLUGINFILES}"
