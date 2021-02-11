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

import json, re, asyncio, aiohttp, uuid, base64
import policysync.metrics as metrics
from . import get_module_logger

logger = get_module_logger(__name__)

# Websocket config
WS_HEARTBEAT = 60
WS_NOTIFICATIONS_ENDPOINT = "pdp/notifications"
# REST config
V1_DECISION_ENDPOINT="policy/pdpx/v1/decision"
V0_DECISION_ENDPOINT = "pdp/api"

APPLICATION_JSON = "application/json"


def get_single_regex(filters, ids):
    filters = [] if filters is None else filters
    ids = [] if ids is None else ["{}[.][0-9]+[.]xml".format(x) for x in ids]
    return "|".join(filters + ids) if filters is not None else ""


class BasePolicyClient:
    def _init_rest_session(self):
        if self.session is None:
            self.session = aiohttp.ClientSession(
                headers=self.headers, raise_for_status=True
            )

        return self.session

    async def _run_request(self, endpoint, filters=None, ids=[]):
        regex = get_single_regex(filters, ids)

        session = self._init_rest_session()
        async with session.post(
            "{0}/{1}".format(self.pdp_url, endpoint), json={"policyName": regex}
        ) as r:
            data = await r.read()

        return json.loads(data)

    def supports_notifications(self):
        return True 

    async def list_policies(self, filters=None, ids=[]):
        raise NotImplementedError

    async def get_config(self, filters=[], ids=[]):
        raise NotImplementedError

    async def notificationhandler(self, callback, ids=[], filters=[]):
        raise NotImplementedError

    async def close(self):
        logger.info("closing websocket clients...")
        if self.session:
            await self.session.close()


class PolicyClientV0(BasePolicyClient):
    """
    Supports the legacy v0 policy API use prior to ONAP Dublin
    """
    async def close(self):
        await super().close()
        if self.ws_session is not None:
            await self.ws_session.close()
        

    def __init__(self, headers, pdp_url, decision_endpoint=V0_DECISION_ENDPOINT, ws_endpoint=WS_NOTIFICATIONS_ENDPOINT):
        self.headers = headers
        self.ws_session = None
        self.session = None
        self.pdp_url = pdp_url
        self.decision_endpoint=decision_endpoint
        self.ws_endpoint=ws_endpoint
        self._ws = None

    def _init_ws_session(self):
        if self.ws_session is None:
            self.ws_session = aiohttp.ClientSession()

        return self.ws_session

    @metrics.list_policy_exceptions.count_exceptions()
    async def list_policies(self, filters=None, ids=[]):
        policies = await self._run_request(
            f"{self.decision_endpoint}/listPolicy", filters=filters, ids=ids
        )
        return set(policies)

    @metrics.get_config_exceptions.count_exceptions()
    async def get_config(self, filters=None, ids=[]):
        """
        Used to get the actual policy configuration from PDP
        :return: the policy objects that are currently active for the given set of filters
        """
        policies = await self._run_request(f"{self.decision_endpoint}/getConfig", filters=filters, ids=ids)
        for policy in policies:
            try:
                policy["config"] = json.loads(policy["config"])
            except Exception:
                pass

        return policies

    def _needs_update(self, update, ids=[], filters=[]):
        """
        Expect something like this
            {
                "removedPolicies": [{
                    "policyName": "DCAE.Config_MS_AGING_UVERSE_PROD_Tosca_HP_AGING_Model_cl55973_IT64_testAging.45.xml",
                    "versionNo": "45"
                }],
                "loadedPolicies": [{
                    "policyName": "DCAE.Config_MS_AGING_UVERSE_PROD_Tosca_HP_AGING_Model_cl55973_IT64_testAging.46.xml",
                    "versionNo": "46",
                    "matches": {
                        "ONAPName": "DCAE",
                        "ConfigName": "DCAE_HighlandPark_AgingConfig",
                        "service": "DCAE_HighlandPark_AgingConfig",
                        "guard": "false",
                        "location": " Edge",
                        "TTLDate": "NA",
                        "uuid": "TestUUID",
                        "RiskLevel": "5",
                        "RiskType": "default"
                    },
                    "updateType": "UPDATE"
                }],
                "notificationType": "BOTH"
            }
        """
        for policy in update.get("removedPolicies", []) + update.get(
            "loadedPolicies", []
        ):
            if (
                re.match(get_single_regex(filters, ids), policy["policyName"])
                is not None
            ):
                return True

        return False

    async def notificationhandler(self, callback, ids=[], filters=[]):
        url = self.pdp_url.replace("https", "wss")
        # The websocket we start here will periodically send heartbeat (ping frames) to policy
        # this ensures that we are never left hanging with our communication with policy.
        session = self._init_ws_session()
        ws = await session.ws_connect(
            "{0}/{1}".format(url, self.ws_endpoint), heartbeat=WS_HEARTBEAT
        )
        logger.info("websock with policy established")
        async for msg in ws:
            # check for websocket errors and break out of this async for loop. to attempt reconnection
            if msg.type in (aiohttp.WSMsgType.CLOSED, aiohttp.WSMsgType.ERROR):
                break
            elif msg.type is (aiohttp.WSMsgType.TEXT):
                if self._needs_update(json.loads(msg.data), ids=ids, filters=filters):
                    logger.debug(
                        "notification received from pdp websocket -> {0}".format(msg)
                    )
                    await callback()
            else:
                logger.warning(
                    "unexpected websocket message type received {}".format(msg.type)
                )


class PolicyClientV1(BasePolicyClient):
    """
    Supports the v1 policy API introduced in ONAP's dublin release
    """

    async def close(self):
        await super().close()
        if self.dmaap_session is not None:
            await self.dmaap_session.close()

    def _init_dmaap_session(self):
        if self.dmaap_session is None:
            self.dmaap_session = aiohttp.ClientSession(headers=self.dmaap_headers, raise_for_status=True)

        return self.dmaap_session



    def __init__(self, headers, pdp_url, v1_decision=V1_DECISION_ENDPOINT, dmaap_url=None, dmaap_timeout=15000, dmaap_headers={}):
        self.headers = headers
        self.session = None
        self.pdp_url = pdp_url
        self._ws = None
        self.audit_uuid = str(uuid.uuid4())
        self.dmaap_url = dmaap_url
        self.dmaap_timeout = dmaap_timeout
        self.dmaap_session = None
        self.dmaap_headers = dmaap_headers
        self.decision = v1_decision

    async def _run_request(self, endpoint, filters=[], ids=[]):
        if len(filters) != 0:
            logger.warning("ignoring filters...v1 API does not support policy filtering yet")
        session = self._init_rest_session()    
        async with session.post(
            "{0}/{1}".format(self.pdp_url, endpoint), json={
                "ONAPName": "DCAE",
                "ONAPComponent": "policy-sync",
                "ONAPInstance": self.audit_uuid,
                "action": "configure",
                "resource": {"policy-id": ids}
            }
        ) as r:
            data = await r.read()

        return json.loads(data)


    async def list_policies(self, filters=[], ids=[]):
        # ONAP has no real equivalent to this as far as I can tell...so we'll always run decision
        return None

    def convert_to_policy(self, policy_body):
        pdp_metadata = policy_body.get("metadata", {})
        policy_id = pdp_metadata.get("policy-id")
        policy_version = policy_body.get("version")
        if not policy_id or policy_version is None:
            logger.warning("Malformed policy is missing policy-id and version")
            return None

        policy_body["policyName"] = "{}.{}.xml".format(
            policy_id, str(policy_version.replace(".", "-"))
        )
        policy_body["policyVersion"] = str(policy_version)
        if "properties" in policy_body:
            policy_body["config"] = policy_body["properties"]
            del policy_body["properties"]

        return policy_body

    @metrics.get_config_exceptions.count_exceptions()
    async def get_config(self, filters=[], ids=[]):
        """
        Used to get the actual policy configuration from PDP
        :return: the policy objects that are currently active for the given set of filters
        """
        data = await self._run_request(self.decision, filters=filters, ids=ids)
        out = []
        for policy_body in data["policies"].values():
            policy = self.convert_to_policy(policy_body)
            if policy is not None:
                out.append(policy)

        return out

    def supports_notifications(self):
        
        return self.dmaap_url is not None

    def _needs_update(self, update, ids):
        """
        expect something like this
        {
            "deployed-policies": [
                {
                    "policy-type": "onap.policies.monitoring.tcagen2",
                    "policy-type-version": "1.0.0",
                    "policy-id": "onap.scaleout.tca",
                    "policy-version": "2.0.0",
                    "success-count": 3,
                    "failure-count": 0
                }
            ],
            "undeployed-policies": [
                {
                    "policy-type": "onap.policies.monitoring.tcagen2",
                    "policy-type-version": "1.0.0",
                    "policy-id": "onap.firewall.tca",
                    "policy-version": "6.0.0",
                    "success-count": 3,
                    "failure-count": 0
                }
            ]
        }
        """
        for policy in update.get("deployed-policies", []) + update.get(
            "undeployed-policies", []
        ):
            if policy.get("policy-id") in ids:
                return True


    async def poll_dmaap(self, callback, ids=[], filters=[]):
            url = f"{self.dmaap_url}/{self.audit_uuid}/0?timeout={self.dmaap_timeout}"
            logger.info(f"polling topic: {url}")
            session = self._init_dmaap_session()
            async with session.get(url) as r:
                messages = await r.read()

                for msg in json.loads(messages):
                    if self._needs_update(json.loads(msg), ids):
                        logger.info(
                            "notification received from dmaap -> {0}".format(msg)
                        )
                        await callback()

    async def notificationhandler(self, callback, ids=[], filters=[]):
        
        while True:
            await self.poll_dmaap(callback, ids=ids, filters=filters)



def get_client(
    pdp_url,
    pdp_user=None,
    pdp_password=None,
    use_v0=False,
    v0_decision=V0_DECISION_ENDPOINT,
    v0_notifications=WS_NOTIFICATIONS_ENDPOINT,
    v1_decision=V1_DECISION_ENDPOINT,
    dmaap_url=None,
    dmaap_user=None,
    dmaap_password=None,
):
    if pdp_url is None:
        raise ValueError("POLICY_SYNC_PDP_URL set or --pdp flag not set")

    pdp_headers = {"Accept": APPLICATION_JSON, "Content-Type": APPLICATION_JSON}
    if pdp_user and pdp_password:
        auth = base64.b64encode("{}:{}".format(pdp_user, pdp_password).encode("utf-8"))
        pdp_headers["Authorization"] = "Basic {}".format(auth.decode("utf-8"))

    dmaap_headers = {"Accept": APPLICATION_JSON, "Content-Type": APPLICATION_JSON}
    if dmaap_user and dmaap_password:
        auth = base64.b64encode("{}:{}".format(dmaap_user, dmaap_password).encode("utf-8"))
        dmaap_headers["Authorization"] = "Basic {}".format(auth.decode("utf-8"))

    # Create client (either v0 or v1) based on arguments)
    return (
        PolicyClientV0(pdp_headers, pdp_url, decision_endpoint=v0_decision, ws_endpoint=v0_notifications)
        if use_v0
        else PolicyClientV1(pdp_headers, pdp_url, v1_decision=v1_decision, dmaap_url=dmaap_url, dmaap_headers=dmaap_headers)
    )
