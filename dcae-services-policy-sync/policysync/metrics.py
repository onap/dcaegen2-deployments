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
""" counters and gaugages for various metrics """
from prometheus_client import Counter, Gauge


policy_updates_counter = Counter(
    "policy_updates", "Number of total policy updates commited"
)
websock_closures = Counter(
    "websocket_errors_and_closures", "Number of websocket closures or errors"
)
list_policy_exceptions = Counter(
    "list_policy_exception",
    "Exceptions that have occured as a result of calling listPolicy",
)
get_config_exceptions = Counter(
    "get_config_exception",
    "Exceptions that have occured as a result of calling getConfig",
)

active_policies_gauge = Gauge(
    "active_policies",
    "Number of policies that have been retrieved off the PDP"
)
