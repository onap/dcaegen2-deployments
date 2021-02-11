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

import asyncio, aiohttp, json, re, uuid, os, tempfile, shutil
from datetime import datetime
from . import get_module_logger
import policysync.metrics as metrics

logger = get_module_logger(__name__)

ACTION_GATHERED = "gathered"
ACTION_UPDATED = "updated"
OUTFILE_INDENT = 4


class Inventory:
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
        return await self.update()

    async def close(self):
        await self.client.close()

    def _atomic_dump(self, data):
        try:
            tf = tempfile.NamedTemporaryFile(
                delete=False,
                dir=os.path.dirname(self.file),
                prefix=os.path.basename(self.file),
                mode="w",
            )
            try:
                tf.write(data)
            finally:
                # fsync the file so its on disk
                tf.flush()
                os.fsync(tf.fileno())
        finally:
            tf.close()

        os.rename(tf.name, os.path.abspath(self.file))

    async def get_policy_content(self, action=ACTION_UPDATED):
        try:
            logger.info(f"Starting policy update process...")
            policy_bodies = await self.client.get_config(
                filters=self.policy_filters, ids=self.policy_ids
            )
            ## match the format a bit of the Config Binding Service
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
            tmp = set(
                [x.get("policyName") for x in policy_bodies if "policyName" in x]
            )

            if tmp != self.hp_active_inventory:
                data = json.dumps(out)
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, self._atomic_dump, data)
                logger.info(f"Update complete. Policies dumped to: {self.file}")
                self.hp_active_inventory = tmp
            else:
                logger.info(f"No updates needed for now")

        except Exception:
            logger.exception("An exception occured while updating the policies")

    async def _sync_inventory(self, action):
        """
        Pull an inventory of policies. Commit changes if there is a change.
        return: boolean to represent whether changes were commited
        """
        try:
            pdp_inventory = await self.client.list_policies(
                filters=self.policy_filters, ids=self.policy_ids
            )
        except Exception:
            logger.exception(
                "An exception occured while getting the available policies from the PDP"
            )
            return False

        logger.debug("pdp_inventory -> {0}".format(pdp_inventory))

        # Below needs to be under a lock because of the call to getConfig being awaited.
        async with self.get_lock:
            if self.hp_active_inventory != pdp_inventory or pdp_inventory is None:

                # Log a delta of what has changed related to this policy update
                if pdp_inventory is not None and self.hp_active_inventory is not None:
                    logger.info(
                        "PDP indicates the following changes have been made...initating update: {} ".format(
                            json.dumps(
                                {
                                    "removed": list(
                                        self.hp_active_inventory - pdp_inventory
                                    ),
                                    "added": list(
                                        pdp_inventory - self.hp_active_inventory
                                    ),
                                }
                            )
                        )
                    )

                await self.get_policy_content(action)
                return True
            else:
                logger.info(
                    "local inventory matches pdp inventory. no update required for now"
                )
                return False
