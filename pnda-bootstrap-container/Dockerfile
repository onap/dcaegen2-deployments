# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2018 Cisco Systems. All rights reserved.
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

FROM python:2.7.15 as build

ARG PNDACLITAG=release/5.0
ARG PLATFORMSALTTAG=release/5.0

RUN git clone -b $PNDACLITAG https://github.com/pndaproject/pnda-cli.git
RUN git clone -b $PLATFORMSALTTAG https://github.com/pndaproject/platform-salt.git

RUN pip2 install --no-cache-dir -r pnda-cli/cli/requirements.txt --install-option="--prefix=/install"

FROM python:2.7.15-alpine3.8
COPY --from=build /install /usr/local
COPY --from=build /pnda-cli /pnda-cli
COPY --from=build /platform-salt /platform-salt

RUN apk add --no-cache curl jq openssl openssh
