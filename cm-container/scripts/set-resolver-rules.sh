#!/bin/bash
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2019 AT&T Intellectual Property. All rights reserved.
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

set -ex
EXTRA_RULES=/opt/manager/extra-resolver-rules
PY=/opt/manager/env/bin/python
# Wait for Cloudify Manager to come up
while ! /scripts/cloudify-ready.sh
do
    echo "Waiting for CM to come up"
    sleep 15
done

if [[ -s ${EXTRA_RULES} && -r ${EXTRA_RULES} ]]
then
    # Capture current resolver rules and append to new rules
    ${PY} /scripts/update_resolver.py --dry-run | egrep "^-" >> ${EXTRA_RULES}

    # Update the resolver rules
    ${PY} /scripts/update_resolver.py ${EXTRA_RULES}
    systemctl restart cloudify-restservice.service
    mv ${EXTRA_RULES} ${EXTRA_RULES}-loaded
fi