#!/bin/bash
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2019-2020 AT&T Intellectual Property. All rights reserved.
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
# Checking Cloudify Manager readiness by looking
# for non-running services
# Relying on the output format of the "cfy status" command.
# A successful execution of the command outputs:
#
# cfy status
# Retrieving manager services status... [ip=localhost]
#
# Services:
# +--------------------------------+---------+
# |            service             |  status |
# +--------------------------------+---------+
# | InfluxDB                       | running |
# | Logstash                       | running |
# | AMQP InfluxDB                  | running |
# | RabbitMQ                       | running |
# | Webserver                      | running |
# | Management Worker              | running |
# | PostgreSQL                     | running |
# | Cloudify Console               | running |
# | Manager Rest-Service           | running |
# | Riemann                        | running |
# +--------------------------------+---------+
#
# or:
#
# cfy status
# Retrieving manager services status... [ip=dcae-cloudify-manager]
#
# Services:
# +--------------------------------+--------+
# |            service             | status |
# +--------------------------------+--------+
# | Cloudify Console               | Active |
# | PostgreSQL                     | Active |
# | AMQP-Postgres                  | Active |
# | Manager Rest-Service           | Active |
# | RabbitMQ                       | Active |
# | Webserver                      | Active |
# | Management Worker              | Active |
# +--------------------------------+--------+
#
# When an individual service is not running, it will have a status other than "running" or "Active".
# If the Cloudify API cannot be reached, the "Services:" line will not appear.

STAT=$(cfy status)
if (echo "${STAT}" | grep "^Services:$")
then
   echo "Got a status response"
   if !(echo "${STAT}" | egrep '^\| [[:alnum:]]+'| egrep -iv ' Active | running ')
   then
      echo "All services running"
      exit 0
   else
      echo "Some service(s) not running"
   fi
else
  echo "Did not get a status response"
fi
echo "${STAT}"
exit 1
