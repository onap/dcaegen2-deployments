#!/bin/bash
#############################################################################
#
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#############################################################################

docker login nexus3.onap.org:10001 -u docker -p docker

docker pull postgres:9.5
docker pull consul:0.8.3
docker pull nginx:latest
docker pull onapdcae/registrator:v7
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.platform.configbinding:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.collectors.ves.vescollector:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.deployments.tca-cdap-container:latest
docker pull nexus3.onap.org:10001/onap/holmes/engine-management:latest
docker pull nexus3.onap.org:10001/onap/holmes/rule-management:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.deployments.cm-container:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.platform.deployment-handler:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.platform.policy-handler:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.platform.servicechange-handler:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.platform.inventory-api:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.services.heartbeat:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.services.prh.prh-app-server:latest
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.collectors.snmptrap:latest
