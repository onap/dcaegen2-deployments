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

import pytest, json, sys, logging, logging.config
from policysync.cmd import Config, main, parsecmd
import policysync.coroutines


class TestConfig:
    def test_parse_args(self):
        args = [
            "--out",
            "out",
            "--pdp-user",
            "chris",
            "--pdp-pass",
            "notapassword",
            "--pdp-url",
            "blah",
            "--duration",
            "60",
            "--filters",
            "[blah]",
        ]

        c = parsecmd(args)

        assert c.filters == ["blah"]
        assert c.check_period == 60
        assert c.out_file == "out"

    def test_parse_args_no_auth(self):
        c = parsecmd(
            ["--out", "out", "--pdp-url", "blah", "--duration", "60", "--filters", "[blah]"]
        )

        assert c.client.pdp_url == "blah"
        assert c.filters == ["blah"]
        assert c.check_period == 60
        assert c.out_file == "out"

    def test_parse_args_no_pdp(self):
        args = []
        with pytest.raises(ValueError):
            parsecmd(args)

    def test_parse_bad_bind(self):
        args = [
            "--out",
            "out",
            "--pdp-user",
            "chris",
            "--pdp-pass",
            "notapassword",
            "--pdp-url",
            "blah",
            "--duration",
            "60",
            "--filters",
            "[blah]",
            "--http-bind",
            "l[ocalhost:100",
        ]

        with pytest.raises(ValueError):
            parsecmd(args)
