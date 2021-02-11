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
"""
Asyncio coroutine setup for both periodic and real time notification tasks """
import signal
import asyncio
from prometheus_client import start_http_server
from .inventory import Inventory
from .util import get_module_logger

SLEEP_ON_ERROR = 10
logger = get_module_logger(__name__)


async def notify_task(inventory, sleep):
    """
    start the notification task
    :param inventory: Inventory
    :param sleep: how long to wait on error in seconds
    """

    logger.info("opening notificationhandler for policy...")
    await inventory.client.notificationhandler(
        inventory.check_and_update,
        ids=inventory.policy_ids,
        filters=inventory.policy_filters,
    )
    logger.warning("websocket closed or errored...will attempt reconnection")
    await asyncio.sleep(sleep)


async def periodic_task(inventory, sleep):
    """
    start the periodic task
    :param inventory: Inventory
    :param sleep: how long to wait between periodic checks
    """
    await asyncio.sleep(sleep)
    logger.info("Executing periodic check of PDP policies")
    await inventory.update()


async def task_runner(inventory, sleep, task, should_run):
    """
    Runs a task in an event loop
    :param inventory: Inventory
    :param sleep: how long to wait between loop iterations
    :param task: coroutine to run
    :param should_run: function for should this task continue to run
    """
    # pylint: disable=broad-except
    while should_run():
        try:
            await task(inventory, sleep)
        except asyncio.CancelledError:
            break
        except Exception:
            logger.exception("Received exception")


async def shutdown(loop, tasks, inventory):
    """
    shutdown the event loop and cancel all tasks
    :param loop: Asyncio eventloop
    :param tasks: list of asyncio tasks
    :param inventory: the inventory object
    """

    logger.info("caught signal")
    # Stop the websocket routines
    for task in tasks:
        task.cancel()
        await task

    # Close the client
    await inventory.close()
    loop.stop()


def _setup_coroutines(
    loop,
    inventory,
    shutdown_handler,
    task_r,
    **kwargs
):
    """ sets up the application coroutines"""
    # Task runner takes a function for stop condition
    # (for testing purposes) but should always run in practice
    # pylint: disable=broad-except
    def infinite_condition():
        return True

    logger.info("Starting gather of all policies...")
    try:
        loop.run_until_complete(inventory.gather())
    except Exception:
        logger.exception('received exception on initial gather')

    # websocket and the periodic check of policies
    tasks = [
        loop.create_task(
            task_r(
                inventory,
                kwargs.get('check_period', 2400),
                periodic_task,
                infinite_condition
            )
        )
    ]

    if inventory.client.supports_notifications():
        tasks.append(
            loop.create_task(
                task_r(
                    inventory,
                    SLEEP_ON_ERROR,
                    notify_task,
                    infinite_condition
                )
            )
        )
    else:
        logger.warning(
            "Defaulting to polling... Provide a dmaap url to receive faster updates"
        )

    # Add shutdown handlers for sigint and sigterm
    for signame in ("SIGINT", "SIGTERM"):
        sig = getattr(signal, signame)
        loop.add_signal_handler(
            sig,
            lambda: asyncio.ensure_future(
                shutdown_handler(loop, tasks, inventory)
            ),
        )

    # Start prometheus server daemonthread for metrics/healthchecking
    if 'bind' in kwargs:
        metrics_server = kwargs.get('metrics_server', start_http_server)
        metrics_server(kwargs['bind'].port, addr=kwargs['bind'].hostname)


def start_event_loop(config):
    """
    start the event loop that runs the application
    :param config: Config object for the application
    """
    loop = asyncio.get_event_loop()
    inventory = Inventory(
        config.filters,
        config.ids,
        config.out_file,
        config.client
    )

    _setup_coroutines(
        loop,
        inventory,
        shutdown,
        task_runner,
        metrics_server=start_http_server,
        bind=config.bind,
        check_period=config.check_period
    )

    loop.run_forever()
    loop.close()
    logger.info("shutdown complete")
