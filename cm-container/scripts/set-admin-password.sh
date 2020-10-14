#!/bin/bash
# ============LICENSE_START=======================================================
# Copyright (c) 2020 AT&T Intellectual Property. All rights reserved.
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
# Runs at deployment time to set cloudify's admin password

set -x

# Wait for Cloudify Manager to come up
while ! /scripts/cloudify-ready.sh
do
    echo "Waiting for CM to come up"
    sleep 15
done

set +x

# Expect Cloudify password to be in file mounted from Kubernetes secret,
# but allow overriding by CMPASS environment variable,
# and if not provided, use the default
CMPASS=${CMPASS:-$(cat /opt/onap/cm-secrets/password 2>/dev/null)}
CMPASS=${CMPASS:-admin}

echo "Set Cloudify's admin password"
cd /opt/manager
cfy_manager --reset_admin_password $CMPASS || ./env/bin/python reset_admin.py -p $CMPASS

echo "Set the password used by the cfy client"
cfy profile set -p $CMPASS

echo "Cloudify password set"