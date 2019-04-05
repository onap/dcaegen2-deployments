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

docker login {{ nexus_docker_repo }} -u {{ nexus_username }} -p {{ nexus_password }}

docker pull postgres:9.5
docker pull consul:0.8.3
docker pull nginx:latest
docker pull onapdcae/registrator:v7
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.platform.configbinding.app-app:{{ dcae_docker_cbs }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.collectors.ves.vescollector:{{ dcae_docker_ves }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.deployments.tca-cdap-container:{{ dcae_docker_tca }}
docker pull {{ nexus_docker_repo }}/onap/holmes/engine-management:{{ holmes_docker_em }}
docker pull {{ nexus_docker_repo }}/onap/holmes/rule-management:{{ holmes_docker_rm }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.platform.inventory-api:{{ dcae_docker_inv }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.platform.servicechange-handler:{{ dcae_docker_sch }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.platform.deployment-handler:{{ dcae_docker_dh }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.platform.policy-handler:{{ dcae_docker_ph }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.collectors.snmptrap:{{ dcae_docker_snmptrap }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.services.prh.prh-app-server:{{ dcae_docker_prh }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.collectors.hv-ves.hv-collector-main:{{ dcae_docker_hvves }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.collectors.datafile.datafile-app-server:{{ dcae_docker_datafile }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.services.mapper.vesadapter.universalvesadaptor:{{ dcae_docker_mua }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.services.mapper.vesadapter.snmpmapper:{{ dcae_docker_msnmp }}
docker pull {{ nexus_docker_repo }}/onap/org.onap.dcaegen2.services.heartbeat:{{ dcae_docker_heartbeat }}
