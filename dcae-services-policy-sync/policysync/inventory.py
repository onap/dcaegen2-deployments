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
""" In memory data store for policies which are currently used by a mS """
import asyncio
import json
import uuid
import os
import tempfile
import aiohttp
from datetime import datetime
from .util import get_module_logger

logger = get_module_logger(__name__)

ACTION_GATHERED = "gathered"
ACTION_UPDATED = "updated"
OUTFILE_INDENT = 4


class Inventory:
    """ In memory data store for policies which are currently used by a mS """
    def __init__(self, filters, ids, outfile, client):
        self.policy_filters = filters
        self.policy_ids = ids
        self.hp_active_inventory = set()
        self.get_lock = asyncio.Lock()
        self.file = outfile
        self.queue = asyncio.Queue()
        self.client = client

    async def gather(self):
        """
        Run at startup to gather an initial inventory of policies
        """
        return await self._sync_inventory(ACTION_GATHERED)

    async def update(self):
        """
        Run to update an inventory of policies on the fly
        """
        return await self._sync_inventory(ACTION_UPDATED)

    async def check_and_update(self):
        """ check and update the policy inventory """
        return await self.update()

    async def close(self):
        """ close the policy inventory and its associated client """
        await self.client.close()

    def _atomic_dump(self, data):
        """ atomically dump the policy content to a file by rename """
        try:
            temp_file = tempfile.NamedTemporaryFile(
                delete=False,
                dir=os.path.dirname(self.file),
                prefix=os.path.basename(self.file),
                mode="w",
            )
            try:
                temp_file.write(data)
            finally:
                # fsync the file so its on disk
                temp_file.flush()
                os.fsync(temp_file.fileno())
        finally:
            temp_file.close()

        os.rename(temp_file.name, os.path.abspath(self.file))
        os.chmod(os.path.abspath(self.file), 0o744)

    async def get_policy_content(self, action=ACTION_UPDATED):
        """
        get the policy content off the PDP
        :param action: what action to present
        :returns: True/False depending on if update was successful
        """
        logger.info("Starting policy update process...")
        try:
            policy_bodies = await self.client.get_config(
                filters=self.policy_filters, ids=self.policy_ids
            )
        except aiohttp.ClientError:
            logger.exception('Conncection Error while connecting to PDP')
            return False
        
        # match the format a bit of the Config Binding Service
        out = {
            "policies": {"items": policy_bodies},
            "event": {
                "action": action,
                "timestamp": (datetime.utcnow().isoformat()[:-3] + "Z"),
                "update_id": str(uuid.uuid4()),
                "policies_count": len(policy_bodies),
            },
        }

        # Atomically dump the file to disk
        tmp = {
            x.get("policyName") for x in policy_bodies if "policyName" in x
        }

        if tmp != self.hp_active_inventory:
            data = json.dumps(out)
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, self._atomic_dump, data)
            logger.info(
                "Update complete. Policies dumped to: %s", self.file
            )
            self.hp_active_inventory = tmp
            return True
        else:
            logger.info("No updates needed for now")
            return False

    async def _sync_inventory(self, action):
        """
        Pull an inventory of policies. Commit changes if there is a change.
        return: boolean to represent whether changes were commited
        """
        try:
            pdp_inventory = await self.client.list_policies(
                filters=self.policy_filters, ids=self.policy_ids
            )
        except aiohttp.ClientError:
            logger.exception("Inventory sync failed due to a connection error")
            return False

        logger.debug("pdp_inventory -> %s", pdp_inventory)

        # Below needs to be under a lock because of
        # the call to getConfig being awaited.
        async with self.get_lock:
            if self.hp_active_inventory != pdp_inventory or \
                 pdp_inventory is None:

                # Log a delta of what has changed related to this policy update
                if pdp_inventory is not None and \
                     self.hp_active_inventory is not None:
                    msg = {
                            "removed": list(
                                self.hp_active_inventory - pdp_inventory
                            ),
                            "added": list(
                                pdp_inventory - self.hp_active_inventory
                            ),
                    }
                    logger.info(
                        "PDP indicates the following changes: %s ", msg
                    )

                return await self.get_policy_content(action)

            logger.info(
                "local matches pdp. no update required for now"
            )
            return False
