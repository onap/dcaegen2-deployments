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

import pytest, json, aiohttp, asyncio
from policysync.inventory import (
    Inventory,
    ACTION_GATHERED,
    ACTION_UPDATED,
)
from tests.mocks import MockClient


class MockMessage:
    def __init__(self, type, data):
        self.type = type
        self.data = data


@pytest.fixture()
def inventory(request, tmpdir):
    f1 = tmpdir.mkdir("sub").join("myfile")
    print(f1)
    return Inventory(["DCAE.Config_MS_AGING_UVERSE_PROD_.*"], [], f1, MockClient())


class TestInventory:
    @pytest.mark.asyncio
    async def test_close(self, inventory):
        await inventory.close()
        assert inventory.client.closed

    @pytest.mark.asyncio
    async def test_get_policy_content(self, inventory):
        await inventory.get_policy_content()
        with open(inventory.file) as f:
            data = json.load(f)

        assert data["policies"] == {
            "items": [
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
        }

        assert data["event"]["action"] == ACTION_UPDATED

    @pytest.mark.asyncio
    async def test_update(self, inventory):
        await inventory.update()
        assert len(inventory.hp_active_inventory) == 1

        assert not await inventory.update()

    @pytest.mark.asyncio
    async def test_update_listpolicies_exception(self, inventory):
        inventory.client.raise_on_listpolicies = True
        assert not await inventory.update()

    @pytest.mark.asyncio
    async def test_update_getconfig_exception(self, inventory):
        inventory.client.raise_on_getconfig = True
        await inventory.get_policy_content()

    @pytest.mark.asyncio
    async def test_gather(self, inventory):
        await inventory.gather()

        # We should gather one policy
        assert len(inventory.hp_active_inventory) == 1

        # type in event should be gather
        with open(inventory.file) as f:
            data = json.load(f)

        assert data["event"]["action"] == ACTION_GATHERED

    @pytest.mark.asyncio
    async def test_ws_text(self, inventory):
        result = await inventory.check_and_update()
        assert result == True
