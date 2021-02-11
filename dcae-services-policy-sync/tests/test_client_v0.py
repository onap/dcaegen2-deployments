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
from policysync.clients import (
    PolicyClientV0 as PolicyClient,
    WS_HEARTBEAT
)


async def listpolicy(request):
    return web.json_response(["hello"])


async def getconfig(request):
    j = [
        {
            "policyConfigMessage": "Config Retrieved!",
            "policyConfigStatus": "CONFIG_RETRIEVED",
            "type": "JSON",
            "config": '{"service":"DCAE_HighlandPark_AgingConfig","location":" Edge","uuid":"TestUUID","policyName":"DCAE.AGING_UVERS_PROD_Tosca_HP_GOC_Model_cl55973_IT64_testAging","configName":"DCAE_HighlandPark_AgingConfig","templateVersion":"1607","priority":"4","version":11.0,"policyScope":"resource=Test1,service=vSCP,type=configuration,closedLoopControlName=vSCP_F5_Firewall_d925ed73_7831_4d02_9545_db4e101f88f8","riskType":"test","riskLevel":"2","guard":"False","content":{"signature":{"filter_clause":"event.faultFields.alarmCondition LIKE(\'%chrisluckenbaugh%\')"},"name":"testAging","context":["PROD"],"priority":1,"prePublishAging":40,"preCorrelationAging":20},"policyNameWithPrefix":"DCAE.AGING_UVERSE_PSL_Tosca_HP_GOC_Model_cl55973_IT64_testAging"}',
            "policyName": "DCAE.Config_MS_AGING_UVERSE_PROD_Tosca_HP_AGING_Model_cl55973_IT64_testAging.78.xml",
            "policyType": "MicroService",
            "policyVersion": "78",
            "matchingConditions": {
                "ECOMPName": "DCAE",
                "ONAPName": "DCAE",
                "ConfigName": "DCAE_HighlandPark_AgingConfig",
                "service": "DCAE_HighlandPark_AgingConfig",
                "uuid": "TestUUID",
                "Location": " Edge",
            },
            "responseAttributes": {},
            "property": None,
        },
        {
            "policyConfigMessage": "Config Retrieved! ",
            "policyConfigStatus": "CONFIG_RETRIEVED",
            "type": "JSON",
            "config": "adlskjfadslkjf",
            "policyName": "DCAE.Config_MS_AGING_UVERSE_PROD_Tosca_HP_AGING_Model_cl55973_IT64_testAging.78.xml",
            "policyType": "MicroService",
            "policyVersion": "78",
            "matchingConditions": {
                "ECOMPName": "DCAE",
                "ONAPName": "DCAE",
                "ConfigName": "DCAE_HighlandPark_AgingConfig",
                "service": "DCAE_HighlandPark_AgingConfig",
                "uuid": "TestUUID",
                "Location": " Edge",
            },
            "responseAttributes": {},
            "property": None,
        },
    ]

    return web.json_response(j)


async def wshandler(request):
    resp = web.WebSocketResponse()
    available = resp.can_prepare(request)
    await resp.prepare(request)
    await resp.send_str('{ "loadedPolicies": [{ "policyName": "bar"}] }')
    await resp.send_bytes(b"bar!!!")
    await resp.close("closed")


@pytest.fixture
def policyclient(aiohttp_client, loop):
    app = web.Application()
    app.router.add_route("POST", "/pdp/api/listPolicy", listpolicy)
    app.router.add_route("POST", "/pdp/api/getConfig", getconfig)
    app.router.add_get("/pdp/notifications", wshandler)
    fake_client = loop.run_until_complete(aiohttp_client(app))
    server = "{}://{}:{}".format("http", fake_client.host, fake_client.port)
    return PolicyClient({}, server)


async def test_listpolicies(policyclient):
    j = await policyclient.list_policies(filters=["bar"])
    assert j == set(["hello"])
    await policyclient.close()
    assert policyclient.session.closed


async def test_getconfig(policyclient):
    j = await policyclient.get_config(filters=["bar"])

    assert j == [
        {
            "policyConfigMessage": "Config Retrieved!",
            "policyConfigStatus": "CONFIG_RETRIEVED",
            "type": "JSON",
            "config": {
                "service": "DCAE_HighlandPark_AgingConfig",
                "location": " Edge",
                "uuid": "TestUUID",
                "policyName": "DCAE.AGING_UVERS_PROD_Tosca_HP_GOC_Model_cl55973_IT64_testAging",
                "configName": "DCAE_HighlandPark_AgingConfig",
                "templateVersion": "1607",
                "priority": "4",
                "version": 11.0,
                "policyScope": "resource=Test1,service=vSCP,type=configuration,closedLoopControlName=vSCP_F5_Firewall_d925ed73_7831_4d02_9545_db4e101f88f8",
                "riskType": "test",
                "riskLevel": "2",
                "guard": "False",
                "content": {
                    "signature": {
                        "filter_clause": "event.faultFields.alarmCondition LIKE('%chrisluckenbaugh%')"
                    },
                    "name": "testAging",
                    "context": ["PROD"],
                    "priority": 1,
                    "prePublishAging": 40,
                    "preCorrelationAging": 20,
                },
                "policyNameWithPrefix": "DCAE.AGING_UVERSE_PSL_Tosca_HP_GOC_Model_cl55973_IT64_testAging",
            },
            "policyName": "DCAE.Config_MS_AGING_UVERSE_PROD_Tosca_HP_AGING_Model_cl55973_IT64_testAging.78.xml",
            "policyType": "MicroService",
            "policyVersion": "78",
            "matchingConditions": {
                "ECOMPName": "DCAE",
                "ONAPName": "DCAE",
                "ConfigName": "DCAE_HighlandPark_AgingConfig",
                "service": "DCAE_HighlandPark_AgingConfig",
                "uuid": "TestUUID",
                "Location": " Edge",
            },
            "responseAttributes": {},
            "property": None,
        },
        {
            "policyConfigMessage": "Config Retrieved! ",
            "policyConfigStatus": "CONFIG_RETRIEVED",
            "type": "JSON",
            "config": "adlskjfadslkjf",
            "policyName": "DCAE.Config_MS_AGING_UVERSE_PROD_Tosca_HP_AGING_Model_cl55973_IT64_testAging.78.xml",
            "policyType": "MicroService",
            "policyVersion": "78",
            "matchingConditions": {
                "ECOMPName": "DCAE",
                "ONAPName": "DCAE",
                "ConfigName": "DCAE_HighlandPark_AgingConfig",
                "service": "DCAE_HighlandPark_AgingConfig",
                "uuid": "TestUUID",
                "Location": " Edge",
            },
            "responseAttributes": {},
            "property": None,
        },
    ]
    await policyclient.close()


async def test_supports_notifications(policyclient):
    assert policyclient.supports_notifications()


async def test_needs_update(policyclient):
    assert policyclient._needs_update(
        {"loadedPolicies": [{"policyName": "bar"}]}, [], ["bar"] 
    )
    assert not policyclient._needs_update(
        {"loadedPolicies": [{"policyName": "bar"}]}, [], ["foo"]
    )


async def test_ws(policyclient):
    async def ws_callback():
        assert True

    await policyclient.notificationhandler(ws_callback, filters=["bar"])
    await policyclient.close()

    assert policyclient.ws_session.closed
