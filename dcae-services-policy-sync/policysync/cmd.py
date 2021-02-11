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

import argparse, os, asyncio, base64, sys, yaml
from . import get_module_logger
from urllib.parse import urlsplit
import policysync.coroutines
import logging
import logging.config
import policysync.clients as clients


logger = get_module_logger(__name__)

APPLICATION_JSON = "application/json"


class Config:
    def __init__(
        self,
        out_file,
        check_period,
        filters,
        ids,
        client,
        bind=None,
    ):
        self.out_file = out_file
        self.check_period = check_period
        self.filters = filters
        self.ids = ids
        self.client = client

        if bind is not None:
            self.bind = urlsplit("//" + bind)


def parsecmd(args):
    parser = argparse.ArgumentParser(
        description="Keeps a JSON file updated with latest policies matching a filter.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument(
        "--out",
        type=str,
        default=os.environ.get("POLICY_SYNC_OUTFILE", "policies.json"),
        help="Output file to dump to",
    )

    parser.add_argument(
        "--duration",
        type=int,
        default=os.environ.get("POLICY_SYNC_DURATION", 1200),
        help="frequency (in seconds) to conduct periodic check",
    )

    parser.add_argument(
        "--filters",
        type=str,
        default=os.environ.get("POLICY_SYNC_FILTER", "[]"),
        help="Regex of policies that you are interested in.",
    )
    parser.add_argument(
        "--ids",
        type=str,
        default=os.environ.get("POLICY_SYNC_ID", "[]"),
        help="Specific names of policies you are interested in.",
    )

    parser.add_argument(
        "--pdp-user",
        type=str,
        default=os.environ.get("POLICY_SYNC_PDP_USER", None),
        help="PDP basic auth username",
    )
    parser.add_argument(
        "--pdp-pass",
        type=str,
        default=os.environ.get("POLICY_SYNC_PDP_PASS", None),
        help="PDP basic auth password",
    )

    parser.add_argument(
        "--pdp-url",
        type=str,
        default=os.environ.get("POLICY_SYNC_PDP_URL", None),
        help="PDP to connect to",
    )

    parser.add_argument(
        "--http-bind",
        type=str,
        default=os.environ.get("POLICY_SYNC_HTTP_BIND", "localhost:8000"),
        help="The bind address (including port) for the sync containers metrics",
    )

    parser.add_argument(
        "--http-metrics",
        type=bool,
        default=os.environ.get("POLICY_SYNC_HTTP_METRICS", True),
        help="turn on or off the prometheus metrics",
    )

    parser.add_argument(
        "--use-v0",
        type=bool,
        default=os.environ.get("POLICY_SYNC_V0_ENABLE", False),
        help="Turn on usage of the legacy v0 policy API",
    )

    parser.add_argument(
        "--logging-config",
        type=str,
        default=os.environ.get("POLICY_SYNC_LOGGING_CONFIG", None),
        help="Python formatted logging configuration file",
    )

    # V0 API specific configuration
    parser.add_argument(
        "--v0-notify-endpoint",
        type=str,
        default=os.environ.get(
            "POLICY_SYNC_V0_NOTIFIY_ENDPOINT", "pdp/notifications"
        ),
        help="Path of the websocket notification endpoint used in v0 api for notifications",
    )

    parser.add_argument(
        "--v0-decision-endpoint",
        type=str,
        default=os.environ.get("POLICY_SYNC_V0_DECISION_ENDPOINT", "pdp/api"),
        help="path of the decision endpoint used in v0 api for notifications",
    )

    # V1 API specific configuration
    parser.add_argument(
        "--v1-dmaap-topic",
        type=str,
        default=os.environ.get("POLICY_SYNC_V1_DMAAP_URL", None),
        help="URL of the dmaap topic used in v1 api for notifications",
    )

    parser.add_argument(
        "--v1-dmaap-user",
        type=str,
        default=os.environ.get("POLICY_SYNC_V1_DMAAP_USER", None),
        help="User to use with with the dmaap topic used in v1 api for notifications",
    )

    parser.add_argument(
        "--v1-dmaap-pass",
        type=str,
        default=os.environ.get("POLICY_SYNC_V1_DMAAP_PASS", None),
        help="Password to use with the dmaap topic used in v1 api for notifications",
    )

    parser.add_argument(
        "--v1-decision-endpoint",
        type=str,
        default=os.environ.get(
            "POLICY_SYNC_V1_PDP_DECISION_ENDPOINT", "policy/pdpx/v1/decision"
        ),
        help="Decision endpoint used in the v1 api for notifications",
    )

    args = parser.parse_args(args)

    if args.logging_config:
        logging.config.fileConfig(args.logging_config, disable_existing_loggers=False)
    else:
        handler = logging.StreamHandler()
        formatter = logging.Formatter("[%(asctime)s][%(levelname)-5s]%(message)s")
        root = logging.getLogger()
        handler.setFormatter(formatter)
        root.addHandler(handler)
        root.setLevel(logging.INFO)

    bind = args.http_bind if args.http_metrics == True else None

    client = clients.get_client(
        args.pdp_url,
        pdp_user=args.pdp_user,
        pdp_password=args.pdp_pass,
        use_v0=args.use_v0,
        v0_decision=args.v0_decision_endpoint,
        v0_notifications=args.v0_notify_endpoint,
        v1_decision=args.v1_decision_endpoint,
        dmaap_url=args.v1_dmaap_topic,
        dmaap_user=args.v1_dmaap_user,
        dmaap_password=args.v1_dmaap_pass
    )

    return Config(
        args.out,
        args.duration,
        yaml.safe_load(args.filters),
        yaml.safe_load(args.ids),
        client,
        bind=bind,
    )


def main():
    # Parse the arguments passed in via the command line
    try:
        config = parsecmd(sys.argv[1:])
    except ValueError:
        logger.error("There was no POLICY_SYNC_PDP_URL set or --pdp flag set")
        return -1
    policysync.coroutines.start_event_loop(config)
