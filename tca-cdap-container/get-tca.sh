#!/bin/bash

PROTO='https'
NEXUSREPO='nexus.onap.org'
REPO='snapshots'
GROUPID='org.onap.dcaegen2.analytics.tca'
ARTIFACTID='dcae-analytics-tca'
VERSION='2.2.0-SNAPSHOT'

URL="${PROTO}://${NEXUSREPO}/service/local/repositories/${REPO}/content/${GROUPID//.//}/${ARTIFACTID}/${VERSION}/maven-metadata.xml"
VT=$(wget --no-check-certificate -O- $URL | grep -m 1 \<value\> | sed -e 's/<value>\(.*\)<\/value>/\1/' | sed -e 's/ //g')

URL="${PROTO}://${NEXUSREPO}/service/local/repositories/${REPO}/content/${GROUPID//.//}/${ARTIFACTID}/${VERSION}/${ARTIFACTID}-${VT}.jar"
#wget --no-check-certificate "${URL}" -O "/opt/tca/${ARTIFACTID}-${VERSION%-SNAPSHOT}.jar"
wget --no-check-certificate "${URL}" -O "${ARTIFACTID}-${VERSION%-SNAPSHOT}.jar"

