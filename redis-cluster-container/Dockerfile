# ================================================================================
# Copyright (c) 2018-2019 AT&T Intellectual Property. All rights reserved.
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
FROM redis:4.0.8
ENV DEBIAN_FRONTEND noninteractive
RUN echo "deb [check-valid-until=no] http://archive.debian.org/debian jessie-backports main" > /etc/apt/sources.list.d/jessie-backports.list
RUN sed -i '/deb http:\/\/deb.debian.org\/debian jessie-updates main/d' /etc/apt/sources.list
RUN apt-get -y -o Acquire::Check-Valid-Until=false update \
  && apt-get -y upgrade \
  && apt-get -y --no-install-recommends install ruby wget jq \
  && gem install redis -v 3.3.5 \
  && apt-get -y autoremove \
  && apt-get -y clean
RUN wget -O /usr/local/bin/redis-trib http://download.redis.io/redis-stable/src/redis-trib.rb
RUN sed -i -e 's/yes_or_die \"/#yes_or_die \"/g' /usr/local/bin/redis-trib
RUN chmod 755 /usr/local/bin/redis-trib
COPY redis-server-config.sh /usr/local/bin/redis-server-config.sh
RUN chmod 755 /usr/local/bin/redis-server-config.sh
#CMD redis-server
CMD redis-server-config.sh
