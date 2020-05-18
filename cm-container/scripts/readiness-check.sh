#!/bin/bash
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2019-2020 AT&T Intellectual Property. All rights reserved.
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
# Check whether Cloudify Manager is ready to take traffic
# Two conditions must be met:
#    -- The import resolver rules must have been updated.
#       This is indicated by the presence of the file named
#       /opt/manager/extra-resolver-rules-loaded.
#    -- All Cloudify Manager services must be running, as
#       indicated by the output of the cfy status command.
#    -- The plugins have been loaded.  This is indicated by the
#       presence of the /opt/manager/plugins-loaded file.

PLUGINS_LOADED=/opt/manager/plugins-loaded

set -x

if [[ -f  $PLUGINS_LOADED ]]
then
  # Check for all services running
  if /scripts/cloudify-ready.sh
  then
    exit 0
  fi
fi
exit 1