#!/bin/bash
# ================================================================================
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
# Copyright (c) 2021 J. F. Lucas.  All rights reserved.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================
# Set up persistent storage for Cloudify Manager's state data

#PDIRS="/var/lib/pgsql/9.5/data /opt/manager/resources /opt/mgmtworker/env/plugins /opt/mgmtworker/work/deployments"
PDIRS="/var/lib /etc/cloudify /opt/cfy /opt/cloudify /opt/cloudify-stage /opt/manager /opt/mgmtworker /opt/restservice"
PSTORE="/cfy-persist"

set -ex

if [ -d "$PSTORE" ] 
then
  # the persistent mount point exists
  if [ -z "$(ls -A $PSTORE)" ]
  then
    # there's nothing in the persistent store yet
    
    # edit the CM config file to set the admin password
    # to our generated value; expect it to be in file
    # mounted from Kubernetes secret, but allow overriding by 
    # CMPASS environment variable, and if not provided, use the default
    CMPASS=${CMPASS:-$(cat /opt/onap/cm-secrets/password 2>/dev/null)}
    CMPASS=${CMPASS:-admin}
    sed -i -e "s|admin_password: .*$|admin_password: ${CMPASS}|" /etc/cloudify/config.yaml
    
    # copy in the data from the container file system
    for d in $PDIRS
    do
      p="$(dirname $d)"
      mkdir -p "${PSTORE}$p"
      cp -rp "$d" "${PSTORE}$p"
    done
  fi
  # at this point, there is persistent storage possibly from a previous startup
  # set up links from internal file system to persistent storage
  for d in $PDIRS
  do
    if [ -d "$d" ]
    then
        mv $d $d-initial        # move directory so we can create symlink
    fi
    ln -sf "$PSTORE/$d" "$(dirname $d)"
  done
else
  echo "No persistent storage available"
fi

# start background script that updates CM password and uploads plugins
/scripts/init-cloudify.sh &
# start up init, which brings up CM and supporting software
exec /sbin/init --log-target=journal 3>&1

