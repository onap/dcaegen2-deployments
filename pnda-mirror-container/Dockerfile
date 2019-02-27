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

FROM centos:7.5.1804 as build

ARG PNDARELEASE=release/5.0
# Can be HDP or CDH
ARG HADOOPDIST=HDP

RUN yum clean all && rm -rf /var/cache/yum/* && yum install gettext git -y

RUN git clone -b $PNDARELEASE https://github.com/pndaproject/pnda.git

COPY pnda-5.0-maint.patch /
WORKDIR /pnda
RUN git apply /pnda-5.0-maint.patch

WORKDIR /pnda/mirror
# Add the -r flag to mirror rpm packages
RUN ./create_mirror.sh -d $HADOOPDIST -r

WORKDIR /pnda/build
RUN ./install-build-tools.sh

RUN yum install bzip2 make which -y
RUN source ./set-pnda-env.sh \
    && PARALLEL="--jobs 1" ./build-pnda.sh RELEASE $PNDARELEASE $HADOOPDIST

FROM nginx:alpine

COPY --from=build /pnda/mirror/mirror-dist /usr/share/nginx/html/
COPY --from=build /pnda/build/pnda-dist /usr/share/nginx/html/
