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

import asyncio, aiohttp, json, signal, functools, re
from prometheus_client import start_http_server
from .inventory import Inventory
from . import get_module_logger

SLEEP_ON_ERROR = 10
logger = get_module_logger(__name__)


async def notify_task(inventory, sleep):
    logger.info("opening notificationhandler for policy...")
    await inventory.client.notificationhandler(
        inventory.check_and_update,
        ids=inventory.policy_ids,
        filters=inventory.policy_filters,
    )
    logger.warning("websocket closed or errored...will attempt reconnection")
    await asyncio.sleep(sleep)


async def periodic_task(inventory, sleep):
    await asyncio.sleep(sleep)
    logger.info("Executing periodic check of PDP policies against local inventory")
    await inventory.update()


async def task_runner(inventory, sleep, task, should_run):
    while should_run():
        try:
            await task(inventory, sleep)
        except asyncio.CancelledError:
            break
        except Exception:
            logger.exception("Received exception")


async def shutdown(sig, loop, tasks, inventory):
    logger.info("caught {0}".format(sig.name))
    # Stop the websocket routines
    for task in tasks:
        task.cancel()
        await task

    # Close the client
    await inventory.close()
    loop.stop()


def _setup_coroutines(
    config, loop, inventory, client, shutdown_handler, task_r, start_metrics_server
):
    # Task runner takes a function for stop condition (for testing purposes) but should always run in practice
    infinite_condition = lambda: True

    logger.info("Starting gather of all policies...2")
    loop.run_until_complete(inventory.gather())

    # websocket and the periodic check of policies
    tasks = [
        loop.create_task(
            task_r(inventory, config.check_period, periodic_task, infinite_condition)
        )
    ]

    if client.supports_notifications():
        tasks.append(
            loop.create_task(
                task_r(inventory, SLEEP_ON_ERROR, notify_task, infinite_condition)
            )
        )
    else:
        logger.warning(
            "Defaulting to polling...Notifications are not supported with this config. Provide a dmaap url to receive faster updates"
        )

    # Add shutdown handlers for sigint and sigterm
    for signame in ("SIGINT", "SIGTERM"):
        sig = getattr(signal, signame)
        loop.add_signal_handler(
            sig,
            lambda: asyncio.ensure_future(
                shutdown_handler(sig, loop, tasks, inventory)
            ),
        )

    # Start prometheus server daemonthread for metrics/healthchecking
    if config.bind:
        start_metrics_server(config.bind.port, addr=config.bind.hostname)


def start_event_loop(config):
    loop = asyncio.get_event_loop()
    inventory = Inventory(config.filters, config.ids, config.out_file, config.client)

    _setup_coroutines(
        config,
        loop,
        inventory,
        inventory.client,
        shutdown,
        task_runner,
        start_http_server,
    )

    loop.run_forever()
    loop.close()
    logger.info("shutdown complete")
