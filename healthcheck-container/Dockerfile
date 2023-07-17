# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2018-2020 AT&T Intellectual Property. All rights reserved.
# Copyright (c) 2021, 2023 J. F. Lucas.  All rights reserved.
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
#
FROM node:18.16.1-alpine3.18
RUN mkdir -p /opt/app \
  && adduser -D -h /opt/app health
COPY *.js /opt/app/
COPY package.json /opt/app/
RUN chown -R health:health /opt/app
WORKDIR /opt/app
USER health
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/node", "healthcheck.js"]
