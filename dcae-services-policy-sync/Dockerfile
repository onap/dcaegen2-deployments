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

FROM nexus3.onap.org:10001/onap/integration-python:7.0.1 as build


USER root

RUN python3 -m venv /policysync
# Need GCC, musl and associated dependencies to compile dependencies against musl
RUN apk add --no-cache --virtual .build-deps gcc musl-dev

WORKDIR /app


# Install dependencies first to speed up builds 
ADD setup.py setup.py
RUN /policysync/bin/pip install -e .

# Add the code now
ADD policysync policysync 
RUN /policysync/bin/pip install .

FROM nexus3.onap.org:10001/onap/integration-python:7.0.1 as runtime

COPY --from=build /policysync /policysync

USER onap
ENTRYPOINT [ "/policysync/bin/policysync" ]




