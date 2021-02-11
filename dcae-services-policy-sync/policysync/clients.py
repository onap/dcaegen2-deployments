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
"""Clients for communicating with both the post dublin and pre dublin APIs"""
import json
import re
import base64
import uuid
import asyncio
import aiohttp
import policysync.metrics as metrics
from .util import get_module_logger

logger = get_module_logger(__name__)

# Websocket config
WS_HEARTBEAT = 60
WS_NOTIFICATIONS_ENDPOINT = "pdp/notifications"
# REST config
V1_DECISION_ENDPOINT = "policy/pdpx/v1/decision"
V0_DECISION_ENDPOINT = "pdp/api"

APPLICATION_JSON = "application/json"


def get_single_regex(filters, ids):
    """given a list of filters and ids returns a single regex for matching"""
    filters = [] if filters is None else filters
    ids = [] if ids is None else ["{}[.][0-9]+[.]xml".format(x) for x in ids]
    return "|".join(filters + ids) if filters is not None else ""


class BasePolicyClient:
    """ Base policy client that is pluggable into inventory """
    def __init__(self, pdp_url, headers=None):
        self.headers = {} if headers is None else headers
        self.session = None
        self.pdp_url = pdp_url

    def _init_rest_session(self):
        """
        initialize an aiohttp rest session
        :returns: an aiohttp rest session
        """
        if self.session is None:
            self.session = aiohttp.ClientSession(
                headers=self.headers, raise_for_status=True
            )

        return self.session

    async def _run_request(self, endpoint, request_data):
        """
        execute a particular REST request
        :param endpoint: str rest endpoint to query
        :param request_data: dictionary request data
        :returns:  dictionary response data
        """
        session = self._init_rest_session()
        async with session.post(
            "{0}/{1}".format(self.pdp_url, endpoint), json=request_data
        ) as resp:
            data = await resp.read()
            return json.loads(data)

    def supports_notifications(self):
        """
        does this particular client support real time notifictions
        :returns: True
        """
        # in derived classes we may use self
        # pylint: disable=no-self-use
        return True

    async def list_policies(self, filters=None, ids=None):
        """
        used to get a list of policies matching a particular ID
        :param filters: list of regex filter strings for matching
        :param ids: list of id strings for matching
        :returns: List of policies matching filters or ids
        """
        raise NotImplementedError

    async def get_config(self, filters=None, ids=None):
        """
        used to get a list of policies matching a particular ID
        :returns: List of policies matching filters or ids
        """
        raise NotImplementedError

    async def notificationhandler(self, callback, ids=None, filters=None):
        """
        Clients should implement this to support real time notifications
        :param callback: func to execute when a matching notification is found
        :param ids: list of id strings for matching
        """
        raise NotImplementedError

    async def close(self):
        """ close the policy client """
        logger.info("closing websocket clients...")
        if self.session:
            await self.session.close()


class PolicyClientV0(BasePolicyClient):
    """
    Supports the legacy v0 policy API use prior to ONAP Dublin
    """
    async def close(self):
        """ close the policy client """
        await super().close()
        if self.ws_session is not None:
            await self.ws_session.close()

    def __init__(
        self,
        headers,
        pdp_url,
        decision_endpoint=V0_DECISION_ENDPOINT,
        ws_endpoint=WS_NOTIFICATIONS_ENDPOINT
    ):
        """
        Initialize a v0 policy client
        :param headers: Headers to use for policy rest api
        :param pdp_url: URL of the PDP
        :param decision_endpoint: root for the decison API
        :param websocket_endpoint: root of the websocket endpoint
        """
        super().__init__(pdp_url, headers=headers)
        self.ws_session = None
        self.session = None
        self.decision_endpoint = decision_endpoint
        self.ws_endpoint = ws_endpoint
        self._ws = None

    def _init_ws_session(self):
        """initialize a websocket session for notifications"""
        if self.ws_session is None:
            self.ws_session = aiohttp.ClientSession()

        return self.ws_session

    @metrics.list_policy_exceptions.count_exceptions()
    async def list_policies(self, filters=None, ids=None):
        """
        used to get a list of policies matching a particular ID
        :param filters: list of regex filter strings for matching
        :param ids: list of id strings for matching
        :returns: List of policies matching filters or ids
        """
        request_data = self._prepare_request(filters, ids)
        policies = await self._run_request(
            f"{self.decision_endpoint}/listPolicy", request_data
        )
        return set(policies)

    @classmethod
    def _prepare_request(cls, filters, ids):
        """prepare the request body for the v0 api"""
        regex = get_single_regex(filters, ids)
        return {"policyName": regex}

    @metrics.get_config_exceptions.count_exceptions()
    async def get_config(self, filters=None, ids=None):
        """
        Used to get the actual policy configuration from PDP
        :return: the policy objects that are currently active
        for the given set of filters
        """
        request_data = self._prepare_request(filters, ids)
        policies = await self._run_request(
            f"{self.decision_endpoint}/getConfig", request_data)

        for policy in policies:
            try:
                policy["config"] = json.loads(policy["config"])
            except json.JSONDecodeError:
                pass

        return policies

    @classmethod
    def _needs_update(cls, update, ids=None, filters=None):
        """
        Expect something like this
        {
            "removedPolicies": [{
                "policyName": "xyz.45.xml",
                "versionNo": "45"
            }],
            "loadedPolicies": [{
                "policyName": "xyz.46.xml",
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

    async def notificationhandler(self, callback, ids=None, filters=None):
        """
        websocket based notification handler for
        :param callback: function to execute when
        a matching notification is found
        :param ids: list of id strings for matching
        """

        url = self.pdp_url.replace("https", "wss")

        # The websocket we start here will periodically
        # send heartbeat (ping frames) to policy
        # this ensures that we are never left hanging
        # with our communication with policy.
        session = self._init_ws_session()
        try:
            websocket = await session.ws_connect(
                "{0}/{1}".format(url, self.ws_endpoint), heartbeat=WS_HEARTBEAT
            )
            logger.info("websock with policy established")
            async for msg in websocket:
                # check for websocket errors
                #  break out of this async for loop. to attempt reconnection
                if msg.type in (aiohttp.WSMsgType.CLOSED, aiohttp.WSMsgType.ERROR):
                    break

                if msg.type is (aiohttp.WSMsgType.TEXT):
                    if self._needs_update(
                        json.loads(msg.data),
                        ids=ids,
                        filters=filters
                    ):
                        logger.debug(
                            "notification received from pdp websocket -> %s", msg
                        )
                        await callback()
                else:
                    logger.warning(
                        "unexpected websocket message type received %s", msg.type
                    )
        except aiohttp.ClientError:
            logger.exception("Received connection error with websocket")


class PolicyClientV1(BasePolicyClient):
    """
    Supports the v1 policy API introduced in ONAP's dublin release
    """

    async def close(self):
        """ close the policy client """
        await super().close()
        if self.dmaap_session is not None:
            await self.dmaap_session.close()

    def _init_dmaap_session(self):
        """ initialize a dmaap session for notifications """
        if self.dmaap_session is None:
            self.dmaap_session = aiohttp.ClientSession(
                    headers=self.dmaap_headers,
                    raise_for_status=True
                )

        return self.dmaap_session

    def __init__(
        self,
        headers,
        pdp_url,
        **kwargs,
    ):
        super().__init__(pdp_url, headers=headers)
        self._ws = None
        self.audit_uuid = str(uuid.uuid4())
        self.dmaap_url = kwargs.get('dmaap_url')
        self.dmaap_timeout = 15000
        self.dmaap_session = None
        self.dmaap_headers = kwargs.get('dmaap_headers', {})
        self.decision = kwargs.get('v1_decision', V1_DECISION_ENDPOINT)

    async def list_policies(self, filters=None, ids=None):
        """
        ONAP has no real equivalent to this.
        :returns: None
        """
        # in derived classes we may use self
        # pylint: disable=no-self-use
        return None

    @classmethod
    def convert_to_policy(cls, policy_body):
        """
        Convert raw policy to format expected by microservices
        :param policy_body: raw dictionary output from pdp
        :returns: data in proper formatting
        """
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
    async def get_config(self, filters=None, ids=None):
        """
        Used to get the actual policy configuration from PDP
        :returns: the policy objects that are currently active
        for the given set of filters
        """
        if ids is None:
            ids = []

        request_data = {
                "ONAPName": "DCAE",
                "ONAPComponent": "policy-sync",
                "ONAPInstance": self.audit_uuid,
                "action": "configure",
                "resource": {"policy-id": ids}
        }

        data = await self._run_request(self.decision, request_data)
        out = []
        for policy_body in data["policies"].values():
            policy = self.convert_to_policy(policy_body)
            if policy is not None:
                out.append(policy)

        return out

    def supports_notifications(self):
        """
        Does this policy client support real time notifications
        :returns: True if the dmaap url is set else return false
        """
        return self.dmaap_url is not None

    @classmethod
    def _needs_update(cls, update, ids):
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

        return False

    async def poll_dmaap(self, callback, ids=None):
        """
        one GET request to dmaap
        :param callback: function to execute when a
        matching notification is found
        :param ids: list of id strings for matching
        """
        query = f"?timeout={self.dmaap_timeout}"
        url = f"{self.dmaap_url}/{self.audit_uuid}/0{query}"
        logger.info("polling topic: %s", url)
        session = self._init_dmaap_session()
        try:
            async with session.get(url) as response:
                messages = await response.read()

                for msg in json.loads(messages):
                    if self._needs_update(json.loads(msg), ids):
                        logger.info(
                            "notification received from dmaap -> %s", msg
                        )
                        await callback()
        except aiohttp.ClientError:
            logger.exception('received connection error from dmaap topic')
            # wait some time
            await asyncio.sleep(30)

    async def notificationhandler(self, callback, ids=None, filters=None):
        """
        dmaap based notification handler for
        :param callback: function to execute when a
        matching notification is found
        :param ids: list of id strings for matching
        """
        if filters is not None:
            logger.warning("filters are not supported with pdp v1..ignoring")
        while True:
            await self.poll_dmaap(callback, ids=ids)


def get_client(
    pdp_url,
    use_v0=False,
    **kwargs
):
    """
    get a particular policy client
    :param use_v0: whether this should be a v0 client or
    :return: A policy client
    """
    if pdp_url is None:
        raise ValueError("POLICY_SYNC_PDP_URL set or --pdp flag not set")

    pdp_headers = {
        "Accept": APPLICATION_JSON,
        "Content-Type": APPLICATION_JSON
    }

    if 'pdp_user' in kwargs and 'pdp_password' in kwargs:
        auth = base64.b64encode(
            "{}:{}".format(
                    kwargs.get('pdp_user'),
                    kwargs.get('pdp_password')
                ).encode("utf-8")
        )
        pdp_headers["Authorization"] = "Basic {}".format(auth.decode("utf-8"))

    dmaap_headers = {
        "Accept": APPLICATION_JSON,
        "Content-Type": APPLICATION_JSON
    }

    logger.info(kwargs.get('dmaap_password'))
    if 'dmaap_user' in kwargs and 'dmaap_password' in kwargs:
        auth = base64.b64encode(
            "{}:{}".format(
                    kwargs.get('dmaap_user'),
                    kwargs.get('dmaap_password')
                ).encode("utf-8")
        ).decode("utf-8")
        dmaap_headers["Authorization"] = f"Basic {auth}"

    # Create client (either v0 or v1) based on arguments)
    if use_v0:
        return PolicyClientV0(
            pdp_headers,
            pdp_url,
            decision_endpoint=kwargs.get('v0_decision'),
            ws_endpoint=kwargs.get('v0_notifications')
        )

    return PolicyClientV1(
        pdp_headers,
        pdp_url,
        v1_decision=kwargs.get('v1_decision'),
        dmaap_url=kwargs.get('dmaap_url'),
        dmaap_headers=dmaap_headers
    )
