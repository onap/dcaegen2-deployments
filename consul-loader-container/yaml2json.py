#!/usr/bin/env python
# ================================================================================
# Copyright (c) 2021 J. F. Lucas. All rights reserved.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================
#
import yaml
import json
import sys

def _yaml_to_json (y):
    return json.dumps(yaml.safe_load(y), indent=2)

def main():
    try:
        print (_yaml_to_json(sys.stdin.read()))
    except Exception as e:
        print(e, file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()