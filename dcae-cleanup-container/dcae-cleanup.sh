#!/bin/sh
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

# Clean up k8s Services and Deployments created by the DCAE k8s plugin

# Cleanup ontainer has access to the Kubernetes CA cert and
# an access token for the API -- need these to make API calls
CREDDIR=/var/run/secrets/kubernetes.io/serviceaccount
TOKEN=$(cat ${CREDDIR}/token)
AUTH="Authorization: Bearer $TOKEN"
CACERT=${CREDDIR}/ca.crt

# Namespace is also available
NS=$(cat ${CREDDIR}/namespace)

# The k8s plugin labels all of the k8s it deploys
# with a label called "cfydeployment".  The value
# of the label is the name of Cloudify deployment
# that caused the entity to be deployed.
# For cleanup purposes, the value of the label doesn't
# matter.  The existence of the label on an entity
# marks the entity as having been deployed by the
# k8s plugin and therefore in need of cleanup.
SELECTOR="labelSelector=cfydeployment"

# Set up the API endpoints
API="https://kubernetes.default"
SVC=${API}/api/v1/namespaces/${NS}/services
DEP=${API}/apis/apps/v1beta1/namespaces/${NS}/deployments

# Find all of the k8s Services labeled with the Cloudify label
SERVICES=$(curl -Ss --cacert ${CACERT} -H "${AUTH}" ${SVC}?${SELECTOR} | /jq .items[].metadata.name | tr -d '"')

# Find all of the k8s Deployments labeled with the Cloudify label
DEPLOYS=$(curl -Ss --cacert ${CACERT} -H "${AUTH}"  ${DEP}?${SELECTOR} | /jq .items[].metadata.name | tr -d '"')

# Delete all of the k8s Services with the Cloudify label
for s in ${SERVICES}
do
    echo Deleting service $s
    curl -Ss --cacert ${CACERT} -H "${AUTH}" -X DELETE ${SVC}/$s
done

# Delete all of the k8s Deployments with the Cloudify label
# "propagationPolicy=Foreground" tells k8s to delete any children
# of the Deployment (ReplicaSets, Pods) and to hold off on deleting
# the Deployment itself until the children have been deleted
for d in ${DEPLOYS}
do
    echo Deleting deployment $d
    curl -Ss --cacert ${CACERT} -H "${AUTH}" -X DELETE ${DEP}/$d?propagationPolicy=Foreground
done
