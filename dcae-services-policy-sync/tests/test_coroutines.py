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

import pytest, json, sys, asyncio, signal
from tests.mocks import (
    MockClient,
    MockTask,
    MockLoop,
    MockInventory,
    MockConfig,
    MockFileDumper,
)
from policysync.coroutines import (
    shutdown,
    periodic_task,
    notify_task,
    task_runner,
    _setup_coroutines,
    SLEEP_ON_ERROR,
)
import policysync.coroutines as coroutines


async def test_shutdownhandler():
    client = MockClient()
    tasks = [MockTask()]
    loop = MockLoop()
    inventory = MockInventory()

    await shutdown( loop, tasks, inventory)

    # Assert that a shutdown results in all tasks in the loop being canceled
    for x in tasks:
        assert x.canceled

    # ... And the the PDP client is closed
    assert inventory.client.closed

    # ... And that the event loop is stopped
    assert loop.stopped


async def test_periodic():
    inventory = MockInventory()
    await periodic_task(inventory, 1)
    assert inventory.was_updated


async def test_ws():
    inventory = MockInventory()
    await notify_task(inventory, 1)
    assert inventory.was_updated


async def test_task_runner():
    def should_run():
        if should_run.counter == 0:
            should_run.counter += 1
            return True
        else:
            return False

    should_run.counter = 0

    def mocktask(inventory):
        assert True

    await task_runner(MockInventory(), 1, mocktask, should_run)


async def test_task_runner_cancel():
    def should_run():
        if should_run.counter == 0:
            should_run.counter += 1
            return True
        elif should_run.counter == 1:
            # If we get here then fail the test
            assert False, "Task runner should have broken out of loop before this"
            return False

    should_run.counter = 0

    # We create a mock task that raises a cancellation error (sent when a asyncio task is canceled)
    def mocktask(inventory, sleep):
        raise asyncio.CancelledError

    await task_runner(MockInventory(), 1, mocktask, should_run)


def test_setup_coroutines():
    loop = MockLoop()

    def fake_task_runner(inventory, sleep, task, should_run):
        return (sleep, task)

    def fake_shutdown(sig, loop, tasks, client):
        return sig

    def fake_metrics_server(port, addr=None):
        fake_metrics_server.started = True

    fake_metrics_server.started = False

    inventory = MockInventory()
    client = MockClient()
    config = MockConfig()

    _setup_coroutines(
        loop,
        inventory,
        fake_shutdown,
        fake_task_runner,
        metrics_server=fake_metrics_server,
        check_period=config.check_period,
        bind=config.bind,
    )

    # By the end of setup coroutines we should have...

    # Gathered initial set of policies
    assert inventory.was_gathered

    # started the websocket and periodic task running
    assert (SLEEP_ON_ERROR, notify_task) in loop.tasks
    assert (config.check_period, periodic_task) in loop.tasks

    # Signal handlers for SIGINT and SIGTERM
    assert signal.SIGINT in loop.handlers
    assert signal.SIGTERM in loop.handlers
