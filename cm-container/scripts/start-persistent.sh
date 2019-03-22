#!/bin/bash
# ================================================================================
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
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

PDIRS="/var/lib/pgsql/9.5/data /opt/manager/resources /opt/mgmtworker/env/plugins /opt/mgmtworker/work/deployments"
PSTORE="/cfy-persist"

set -ex

if [ -d "$PSTORE" ] 
then
  # the persistent mount point exists
  if [ -z "$(ls -A $PSTORE)" ]
  then
    # there's nothing in the persistent store yet
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
# start up init, which brings up CM and supporting software
exec /sbin/init --log-target=journal 3>&1

