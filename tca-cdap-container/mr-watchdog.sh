#!/bin/bash
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



SUB_TOPIC=${3:-unauthenticated.VES_MEASUREMENT_OUTPUT}
MR_LOCATION=${1:-10.0.11.1}
MR_PORT=${2:-3904}
MR_PROTO='http'


TOPIC_LIST_URL="${MR_PROTO}://${MR_LOCATION}:${MR_PORT}/topics"
TEST_PUB_URL="${MR_PROTO}://${MR_LOCATION}:${MR_PORT}/events/${SUB_TOPIC}"

unset RES
echo "==> Check topic [${SUB_TOPIC}] availbility on ${MR_LOCATION}:${MR_PORT}"
until [ -n "$RES" ]; do
    URL="$TOPIC_LIST_URL"
    HTTP_RESPONSE=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" "$URL")
    HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
    HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    if [ "${HTTP_STATUS}" != "200" ]; then
        echo "   ==> MR topic listing not ready, retry in 30 seconds"
        sleep 30
        continue
    fi

    echo "   ==> MR topic listing received, check topic availbility"
    RES=$(echo "${HTTP_BODY}" |jq .topics |grep "\"$SUB_TOPIC\"")
    if [ -z "${RES}" ]; then
        echo "      ==> No topic [${SUB_TOPIC}] found, send test publish"
        URL="$TEST_PUB_URL"
        HTTP_RESPONSE=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" -H "Content-Type:text/plain" -X POST -d "{}" "$URL")
        HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
        HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
         
        if [ "$HTTP_STATUS" != "200" ]; then
            echo "      ==> Testing MR topic publishing received status $HTTP_STATUS != 200, retesting in 30 seconds"
            sleep 30
        else
            echo "      ==> Testing MR topic publishing received status $HTTP_STATUS, topic [$SUB_TOPIC] created"
        fi
    fi
done
echo "==> Topic [${SUB_TOPIC}] ready"
