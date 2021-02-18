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

from urllib.parse import urlsplit
import asyncio, aiohttp


class MockConfig:
    def __init__(self):
        self.check_period = 60
        self.quiet_period = 0
        self.bind = urlsplit("//localhost:8080")


class MockFileDumper:
    def __init__(self):
        self.closed = False

    async def close(self):
        self.closed = True


class MockInventory:
    def __init__(self, queue=None):
        self.was_updated = False
        self.was_gathered = False
        self.client = MockClient()
        self.queue = queue
        self.quiet = 0
        self.updates = []
        self.policy_filters = []
        self.policy_ids = []

    async def update(self):
        self.was_updated = True
        return True

    async def gather(self):
        self.was_gathered = True
        print("got here GATHERED")
        return True

    async def close(self):
        self.client.closed = True

    async def check_and_update(self):
        await self.update()

    async def get_policy_content(self, action="UPDATED"):
        self.updates.append(action)


class MockClient:
    def __init__(self, raise_on_listpolicies=False, raise_on_getconfig=False):
        self.closed = False
        self.opened = False
        self.raise_on_listpolicies = raise_on_listpolicies
        self.raise_on_getconfig = raise_on_getconfig

    async def close(self):
        self.closed = True

    async def notificationhandler(self, callback, ids=[], filters=[]):
        await callback()

    def supports_notifications(self):
        return True

    async def list_policies(self, filters=[], ids=[]):
        if self.raise_on_listpolicies:
            raise aiohttp.ClientError 

        return set(
            [
                "DCAE.Config_MS_AGING_UVERSE_PROD_Tosca_HP_AGING_Model_cl55973_IT64_testAging.78.xml"
            ]
        )

    async def get_config(self, filters=[], ids=[]):
        if self.raise_on_getconfig:
            raise aiohttp.ClientError

        return [
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


class MockLoop:
    def __init__(self):
        self.stopped = False
        self.handlers = []
        self.tasks = []

    def stop(self):
        self.stopped = True

    def add_signal_handler(self, signal, handler):
        self.handlers.append(signal)

    def create_task(self, task):
        self.tasks.append(task)

    def run_until_complete(self, task):
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(task)


class MockTask:
    def __init__(self):
        self.canceled = False

    def cancel(self):
        self.canceled = True

    def __await__(self):
        return iter([])
