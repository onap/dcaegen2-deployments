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

  
ARTIFACTPATH=${1:-/opt/tca/}
PROTO='https'
NEXUSREPO='nexus.onap.org'
GROUPID='org.onap.dcaegen2.analytics.tca'
ARTIFACTID='dcae-analytics-cdap-tca'

#REPO='snapshots'
REPO='releases'
VERSION=''

# if VERSION is not specified, find out the latest version
if [ -z "$VERSION" ]; then
  URL="${PROTO}://${NEXUSREPO}/service/local/repositories/${REPO}/content/${GROUPID//.//}/${ARTIFACTID}/maven-metadata.xml"
  VERSION=$(wget --no-check-certificate -O- $URL | grep -m 1 \<latest\> | sed -e 's/<latest>\(.*\)<\/latest>/\1/' | sed -e 's/ //g')
fi

echo "Getting version $VERSION of $GROUPID.$ARTIFACTID from $REPO repo on $NEXUSREPO"

if [ "$REPO" == "snapshots" ]; then
  # SNOTSHOT repo container many snapshots for each version.  get the newest among them
  URL="${PROTO}://${NEXUSREPO}/service/local/repositories/${REPO}/content/${GROUPID//.//}/${ARTIFACTID}/${VERSION}/maven-metadata.xml"
  VT=$(wget --no-check-certificate -O- "$URL" | grep -m 1 \<value\> | sed -e 's/<value>\(.*\)<\/value>/\1/' | sed -e 's/ //g')
else
  VT=${VERSION}
fi
URL="${PROTO}://${NEXUSREPO}/service/local/repositories/${REPO}/content/${GROUPID//.//}/${ARTIFACTID}/${VERSION}/${ARTIFACTID}-${VT}.jar"
echo "Fetching $URL"

wget --no-check-certificate "${URL}" -O "${ARTIFACTPATH}${ARTIFACTID}.${VERSION}.jar"
