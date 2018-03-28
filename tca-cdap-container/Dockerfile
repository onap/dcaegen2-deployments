# ================================================================================
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
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

FROM caskdata/cdap-standalone:4.1.2

RUN apt-get update
RUN apt-get install -y netcat jq wget
COPY get-tca.sh /opt/tca/get-tca.sh
RUN /opt/tca/get-tca.sh
COPY tca_app_config.json /opt/tca/tca_app_config.json
COPY tca_app_preferences.json /opt/tca/tca_app_preferences.json
COPY restart.sh /opt/tca/restart.sh
COPY host.aliases /etc/host.aliases

RUN echo "export HOSTALIASES=/etc/host.aliases" >> /etc/profile
RUN chmod 755 /opt/tca/restart.sh

ENV HOSTALIASES /etc/host.aliases

EXPOSE 11011
EXPOSE 11015

ENTRYPOINT /opt/tca/restart.sh
