# ============LICENSE_START=======================================================
# Copyright (c) 2021 AT&T Intellectual Property. All rights reserved.
# Copyright (C) 2026 Deutsche Telekom AG. All rights reserved.
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

FROM docker.io/library/python:3.15-slim-trixie AS python-base

FROM python-base AS build
WORKDIR /app
RUN python -m venv /policysync
COPY setup.py ./
COPY policysync/ ./policysync/
RUN /policysync/bin/python -m pip install --no-cache-dir .

FROM python-base AS runtime
COPY --from=build /policysync /policysync

COPY cacert.pem /usr/local/share/ca-certificates/onap.crt
RUN update-ca-certificates

WORKDIR /app
# Match the previous image's runtime UID/GID and file ownership.
RUN groupadd --gid 65533 onap-runtime \
    && groupadd --gid 101 onap \
    && useradd --system --uid 100 --gid onap-runtime --create-home --shell /usr/sbin/nologin onap \
    && chown onap:onap /app /home/onap

USER onap
ENTRYPOINT ["/policysync/bin/policysync"]
