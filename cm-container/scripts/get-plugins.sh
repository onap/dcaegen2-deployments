#!/bin/bash
# ============LICENSE_START=======================================================
# Copyright (c) 2018-2020 AT&T Intellectual Property. All rights reserved.
# Copyright (d) 2020-2021 J. F. Lucas.  All rights reserved.
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

# Pull plugin wagon files and type files from repo
# $1 is the DCAE repo URL - script assumes all files come from the
#    same repo, but not necessarily same paths
#
set -x -e

# Location in CM container where plugins/type files will be stored
# At deployment, CM script will look here to find plugins to upload
DEST=${DEST:-/opt/plugins}

# Each line has a plugin wagon/type file pair, in the form
# /path/to/plugin/wagon|/path/to/type/file
PLUGINS=\
"\
/dcaepolicyplugin/2.4.0/dcaepolicyplugin-2.4.0-py36-none-linux_x86_64.wgn|/dcaepolicyplugin/2.4.0/dcaepolicyplugin_types.yaml \
/relationshipplugin/1.1.0/relationshipplugin-1.1.0-py36-none-linux_x86_64.wgn|/relationshipplugin/1.1.0/relationshipplugin_types.yaml \
/k8splugin/3.9.0/k8splugin-3.9.0-py36-none-linux_x86_64.wgn|/k8splugin/3.9.0/k8splugin_types.yaml \
/clamppolicyplugin/1.1.1/clamppolicyplugin-1.1.1-py36-none-linux_x86_64.wgn|/clamppolicyplugin/1.1.1/clamppolicyplugin_types.yaml \
/dmaap/1.5.1/dmaap-1.5.1-py36-none-linux_x86_64.wgn|/dmaap/1.5.1/dmaap_types.yaml \
/pgaas/1.3.0/pgaas-1.3.0-py36-none-linux_x86_64.wgn|/pgaas/1.3.0/pgaas_types.yaml \
/sshkeyshare/1.2.0/sshkeyshare-1.2.0-py36-none-linux_x86_64.wgn|/sshkeyshare/1.2.0/sshkeyshare_types.yaml
"

mkdir -p ${DEST}

for p in ${PLUGINS}
do
  w=$(echo $p | cut -d '|' -f1)
  t=$(echo $p | cut -d '|' -f2)

  # Put each wagon/type file pair into its own subdirectory
  # This prevents name collisions which can happen because
  # type files don't embed a version.
	subdir=$(mktemp -d -t plugin-XXXXXXX --tmpdir=${DEST})

	curl -Ss -L -f $1/$t >> ${subdir}/$(basename $t)
  curl -Ss -L -f $1/$w >> ${subdir}/$(basename $w)

done

chown -R cfyuser:cfyuser ${DEST}
