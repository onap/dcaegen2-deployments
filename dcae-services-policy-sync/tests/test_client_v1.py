# ============LICENSE_START=======================================================
# Copyright (c) 2021 AT&T Intellectual Property. All rights reserved.
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

from aiohttp import web, WSMsgType
import json, pytest, re
from policysync.clients import PolicyClientV1 as PolicyClient 

DECISION_ENDPOINT = 'policy/pdpx/v1/decision'
async def get_decision(request):
    req_data = await request.json()
    assert req_data['ONAPName'] == 'DCAE'
    assert req_data['ONAPComponent'] == 'policy-sync'
    assert req_data['action'] == 'configure'
    assert req_data['resource'] == {
        'policy-id': [
            'onap.scaleout.tca', 
            'onap.restart.tca'
        ]
    }


    j = {
        "policies": {
            "onap.scaleout.tca": {
                "type": "onap.policies.monitoring.cdap.tca.hi.lo.app",
                "version": "1.0.0",
                "metadata": {"policy-id": "onap.scaleout.tca"},
                "properties": {
                    "tca_policy": {
                        "domain": "measurementsForVfScaling",
                        "metricsPerEventName": [
                            {
                                "eventName": "vLoadBalancer",
                                "controlLoopSchemaType": "VNF",
                                "policyScope": "type=configuration",
                                "policyName": "onap.scaleout.tca",
                                "policyVersion": "v0.0.1",
                                "thresholds": [
                                    {
                                        "closedLoopControlName": "ControlLoop-vDNS-6f37f56d-a87d-4b85-b6a9-cc953cf779b3",
                                        "closedLoopEventStatus": "ONSET",
                                        "version": "1.0.2",
                                        "fieldPath": "$.event.measurementsForVfScalingFields.vNicPerformanceArray[*].receivedBroadcastPacketsAccumulated",
                                        "thresholdValue": 500,
                                        "direction": "LESS_OR_EQUAL",
                                        "severity": "MAJOR",
                                    },
                                    {
                                        "closedLoopControlName": "ControlLoop-vDNS-6f37f56d-a87d-4b85-b6a9-cc953cf779b3",
                                        "closedLoopEventStatus": "ONSET",
                                        "version": "1.0.2",
                                        "fieldPath": "$.event.measurementsForVfScalingFields.vNicPerformanceArray[*].receivedBroadcastPacketsAccumulated",
                                        "thresholdValue": 5000,
                                        "direction": "GREATER_OR_EQUAL",
                                        "severity": "CRITICAL",
                                    },
                                ],
                            }
                        ],
                    }
                },
            },
            "onap.restart.tca": {
                "type": "onap.policies.monitoring.cdap.tca.hi.lo.app",
                "version": "1.0.0",
                "metadata": {"policy-id": "onap.restart.tca", "policy-version": 1},
                "properties": {
                    "tca_policy": {
                        "domain": "measurementsForVfScaling",
                        "metricsPerEventName": [
                            {
                                "eventName": "Measurement_vGMUX",
                                "controlLoopSchemaType": "VNF",
                                "policyScope": "DCAE",
                                "policyName": "DCAE.Config_tca-hi-lo",
                                "policyVersion": "v0.0.1",
                                "thresholds": [
                                    {
                                        "closedLoopControlName": "ControlLoop-vCPE-48f0c2c3-a172-4192-9ae3-052274181b6e",
                                        "version": "1.0.2",
                                        "fieldPath": "$.event.measurementsForVfScalingFields.additionalMeasurements[*].arrayOfFields[0].value",
                                        "thresholdValue": 0,
                                        "direction": "EQUAL",
                                        "severity": "MAJOR",
                                        "closedLoopEventStatus": "ABATED",
                                    },
                                    {
                                        "closedLoopControlName": "ControlLoop-vCPE-48f0c2c3-a172-4192-9ae3-052274181b6e",
                                        "version": "1.0.2",
                                        "fieldPath": "$.event.measurementsForVfScalingFields.additionalMeasurements[*].arrayOfFields[0].value",
                                        "thresholdValue": 0,
                                        "direction": "GREATER",
                                        "severity": "CRITICAL",
                                        "closedLoopEventStatus": "ONSET",
                                    },
                                ],
                            }
                        ],
                    }
                },
            },
        }
    }

    return web.json_response(j)


@pytest.fixture
def policyclient(aiohttp_client, loop):
    app = web.Application()
    app.router.add_route("POST", "/" + DECISION_ENDPOINT, get_decision)
    fake_client = loop.run_until_complete(aiohttp_client(app))
    server = "{}://{}:{}".format("http", fake_client.host, fake_client.port)
    return PolicyClient({}, server)


async def test_getconfig(policyclient):
    j = await policyclient.get_config(ids=['onap.scaleout.tca', 'onap.restart.tca' ])
    assert j == [
        {
            "policy_id": "onap.scaleout.tca",
            "policy_body": {
                "type": "onap.policies.monitoring.cdap.tca.hi.lo.app",
                "version": "1.0.0",
                "metadata": {"policy-id": "onap.scaleout.tca"},
                "policyName": "onap.scaleout.tca.1-0-0.xml",
                "policyVersion": "1.0.0",
                "config": {
                    "tca_policy": {
                        "domain": "measurementsForVfScaling",
                        "metricsPerEventName": [
                            {
                                "eventName": "vLoadBalancer",
                                "controlLoopSchemaType": "VNF",
                                "policyScope": "type=configuration",
                                "policyName": "onap.scaleout.tca",
                                "policyVersion": "v0.0.1",
                                "thresholds": [
                                    {
                                        "closedLoopControlName": "ControlLoop-vDNS-6f37f56d-a87d-4b85-b6a9-cc953cf779b3",
                                        "closedLoopEventStatus": "ONSET",
                                        "version": "1.0.2",
                                        "fieldPath": "$.event.measurementsForVfScalingFields.vNicPerformanceArray[*].receivedBroadcastPacketsAccumulated",
                                        "thresholdValue": 500,
                                        "direction": "LESS_OR_EQUAL",
                                        "severity": "MAJOR",
                                    },
                                    {
                                        "closedLoopControlName": "ControlLoop-vDNS-6f37f56d-a87d-4b85-b6a9-cc953cf779b3",
                                        "closedLoopEventStatus": "ONSET",
                                        "version": "1.0.2",
                                        "fieldPath": "$.event.measurementsForVfScalingFields.vNicPerformanceArray[*].receivedBroadcastPacketsAccumulated",
                                        "thresholdValue": 5000,
                                        "direction": "GREATER_OR_EQUAL",
                                        "severity": "CRITICAL",
                                    },
                                ],
                            }
                        ],
                    }
                },
            },
        },
        {
            "policy_id": "onap.restart.tca",
            "policy_body": {
                "type": "onap.policies.monitoring.cdap.tca.hi.lo.app",
                "version": "1.0.0",
                "metadata": {"policy-id": "onap.restart.tca", "policy-version": 1},
                "policyName": "onap.restart.tca.1-0-0.xml",
                "policyVersion": "1.0.0",
                "config": {
                    "tca_policy": {
                        "domain": "measurementsForVfScaling",
                        "metricsPerEventName": [
                            {
                                "eventName": "Measurement_vGMUX",
                                "controlLoopSchemaType": "VNF",
                                "policyScope": "DCAE",
                                "policyName": "DCAE.Config_tca-hi-lo",
                                "policyVersion": "v0.0.1",
                                "thresholds": [
                                    {
                                        "closedLoopControlName": "ControlLoop-vCPE-48f0c2c3-a172-4192-9ae3-052274181b6e",
                                        "version": "1.0.2",
                                        "fieldPath": "$.event.measurementsForVfScalingFields.additionalMeasurements[*].arrayOfFields[0].value",
                                        "thresholdValue": 0,
                                        "direction": "EQUAL",
                                        "severity": "MAJOR",
                                        "closedLoopEventStatus": "ABATED",
                                    },
                                    {
                                        "closedLoopControlName": "ControlLoop-vCPE-48f0c2c3-a172-4192-9ae3-052274181b6e",
                                        "version": "1.0.2",
                                        "fieldPath": "$.event.measurementsForVfScalingFields.additionalMeasurements[*].arrayOfFields[0].value",
                                        "thresholdValue": 0,
                                        "direction": "GREATER",
                                        "severity": "CRITICAL",
                                        "closedLoopEventStatus": "ONSET",
                                    },
                                ],
                            }
                        ],
                    }
                },
            },
        },
    ]
    await policyclient.close()


async def test_supports_notifications(policyclient):
    assert not policyclient.supports_notifications()
