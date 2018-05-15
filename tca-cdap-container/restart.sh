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

set -e

CDAP_HOST='localhost'
CDAP_PORT='11015'
TCA_NAMESPACE='cdap_tca_hi_lo'
TCA_APPNAME='dcae-tca'

TCA_ARTIFACT='dcae-analytics-cdap-tca'
TCA_FILE_PATH='/opt/tca'
TCA_JAR="$(ls -1r ${TCA_FILE_PATH}/${TCA_ARTIFACT}*.jar | head -1)"
TCA_ARTIFACT_VERSION=$(echo "$TCA_JAR" |rev |cut -f 2-4 -d '.' |rev)
TCA_APP_CONF="${TCA_FILE_PATH}/tca_app_config.json"
TCA_CONF="${TCA_FILE_PATH}/tca_config.json"
TCA_PREF="${TCA_FILE_PATH}/tca_app_preferences.json"
TCA_CONF_TEMP='/tmp/tca_config.json'
TCA_APP_CONF_TEMP='/tmp/tca_app_config.json'
TCA_PREF_TEMP='/tmp/tca_preferences.json'

TCA_PATH_APP="${CDAP_HOST}:${CDAP_PORT}/v3/namespaces/${TCA_NAMESPACE}/apps/${TCA_APPNAME}"
TCA_PATH_ARTIFACT="${CDAP_HOST}:${CDAP_PORT}/v3/namespaces/${TCA_NAMESPACE}/artifacts"

MR_WATCHDOG_PATH="${TCA_FILE_PATH}/mr-watchdog.sh"


WORKER_COUNT='0'

CONSUL_HOST=${CONSUL_HOST:-consul}
CONSUL_PORT=${CONSUL_PORT:-8500}
CONFIG_BINDING_SERVICE=${CONFIG_BINDING_SERVICE:-config_binding_service}

CBS_SERVICE_NAME=${CONFIG_BINDING_SERVICE}

#Changing to HOSTNAME parameter for consistency with k8s deploy
MY_NAME=${HOSTNAME:-tca}


echo "Generting preference file"
DMAAPSUBGROUP=${DMAAPSUBGROUP:-OpenDCAEc12}
DMAAPSUBID=${DMAAPSUBID:=c12}
sed -i 's/{{DMAAPHOST}}/'"${DMAAPHOST}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPPORT}}/'"${DMAAPPORT}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPPUBTOPIC}}/'"${DMAAPPUBTOPIC}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPSUBTOPIC}}/'"${DMAAPSUBTOPIC}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPSUBGROUP}}/'"${DMAAPSUBGROUP}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPSUBID}}/'"${DMAAPSUBID}"'/g' ${TCA_PREF}
sed -i 's/{{AAIHOST}}/'"${AAIHOST}"'/g' ${TCA_PREF}
sed -i 's/{{AAIPORT}}/'"${AAIPORT}"'/g' ${TCA_PREF}
if [ -z "$REDISHOSTPORT" ]; then
  sed -i 's/{{REDISHOSTPORT}}/NONE/g' ${TCA_PREF}
  sed -i 's/{{REDISCACHING}}/false/g' ${TCA_PREF}
else
  sed -i 's/{{REDISHOSTPORT}}/'"${REDISHOSTPORT}"'/g' ${TCA_PREF}
  sed -i 's/{{REDISCACHING}}/true/g' ${TCA_PREF}
fi

function tca_stop {
    # stop programs
    echo
    echo "Stopping TCADMaaPMRPublisherWorker, TCADMaaPMRSubscriberWorker, and TCAVESCollectorFlow ..."
    echo
    curl -s -X POST "http://${TCA_PATH_APP}/workers/TCADMaaPMRPublisherWorker/stop"
    curl -s -X POST "http://${TCA_PATH_APP}/workers/TCADMaaPMRSubscriberWorker/stop"
    curl -s -X POST "http://${TCA_PATH_APP}/flows/TCAVESCollectorFlow/stop"
    echo "done"
    echo
}

function tca_load_artifact {
    echo
    echo "Loading artifact ${TCA_JAR} to http://${TCA_PATH_ARTIFACT}/${TCA_ARTIFACT}..."
    curl -s -X POST --data-binary @"${TCA_JAR}" "http://${TCA_PATH_ARTIFACT}/${TCA_ARTIFACT}"
    echo
}

function tca_load_conf {
    echo
    echo "Loading configuration ${TCA_APP_CONF} to http://${TCA_PATH_APP}"
    curl -s -X PUT -d @${TCA_APP_CONF} http://${TCA_PATH_APP}
    echo

    # load preferences
    echo
    echo "Loading preferences ${TCA_PREF} to http://${TCA_PATH_APP}/preferences"
    curl -s -X PUT -d @${TCA_PREF} http://${TCA_PATH_APP}/preferences
    echo
}


function tca_delete {
    echo
    echo "Deleting application dcae-tca http://${TCA_PATH_APP}"
    curl -s -X DELETE http://${TCA_PATH_APP}
    echo

    # delete artifact
    echo
    echo "Deleting artifact http://${TCA_PATH_ARTIFACT}/${TCA_ARTIFACT}/versions/${TCA_ARTIFACT_VERSION}   ..."
    curl -s -X DELETE "http://${TCA_PATH_ARTIFACT}/${TCA_ARTIFACT}/versions/${TCA_ARTIFACT_VERSION}"
    echo
}

function tca_start {
    echo
    echo "Starting TCADMaaPMRPublisherWorker, TCADMaaPMRSubscriberWorker, and TCAVESCollectorFlow ..."
    curl -s -X POST "http://${TCA_PATH_APP}/workers/TCADMaaPMRPublisherWorker/start"
    curl -s -X POST "http://${TCA_PATH_APP}/workers/TCADMaaPMRSubscriberWorker/start"
    curl -s -X POST "http://${TCA_PATH_APP}/flows/TCAVESCollectorFlow/start"
    echo
}


function tca_status {
    WORKER_COUNT='0'
    echo
    STATUS=$(curl -s "http://${TCA_PATH_APP}/workers/TCADMaaPMRPublisherWorker/status")
    echo "TCADMaaPMRPublisherWorker status: $STATUS"
    INC=$(echo "$STATUS" | jq . |grep RUNNING |wc -l)
    WORKER_COUNT=$((WORKER_COUNT+INC))

    STATUS=$(curl -s "http://${TCA_PATH_APP}/workers/TCADMaaPMRSubscriberWorker/status")
    echo "TCADMaaPMRSubscriberWorker status: $STATUS"
    INC=$(echo "$STATUS" | jq . |grep RUNNING |wc -l)
    WORKER_COUNT=$((WORKER_COUNT+INC))

    STATUS=$(curl -s "http://${TCA_PATH_APP}/flows/TCAVESCollectorFlow/status")
    echo "TCAVESCollectorFlow status: $STATUS"
    INC=$(echo "$STATUS" | jq . |grep RUNNING |wc -l)
    WORKER_COUNT=$((WORKER_COUNT+INC))
    echo
}


function tca_restart {
    MR_HOST=$(jq .subscriberHostName ${TCA_PREF} |sed -e 's/\"//g')
    MR_PORT=$(jq .subscriberHostPort ${TCA_PREF} |sed -e 's/\"//g')
    MR_TOPIC=$(jq .subscriberTopicName ${TCA_PREF}  |sed -e 's/\"//g')
    echo "Verifying DMaaP topic: ${MR_TOPIC}@${MR_HOST}:${MR_PORT} (will block until topic ready)"
    "${MR_WATCHDOG_PATH}" "${MR_HOST}" "${MR_PORT}" "${MR_TOPIC}"
    tca_stop
    tca_delete
    tca_load_artifact
    tca_load_conf
    tca_start
    sleep 5
    tca_status
}

function tca_poll_policy {
    URL0="${CBS_HOST}:${CBS_PORT}/service_component_all/${MY_NAME}"
    echo "tca_poll_policy: Retrieving all-in-one config at ${URL0}"
    HTTP_RESPONSE=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" "$URL0")
    HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
    HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    if [ "$HTTP_STATUS" != "200" ]; then
        echo "tca_poll_policy: Retrieving all-in-one config failed with status $HTTP_STATUS"
        URL1="${CBS_HOST}:${CBS_PORT}/service_component/${MY_NAME}"
        echo "tca_poll_policy: Retrieving app config only at ${URL1}"
        HTTP_RESPONSE1=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" "$URL1")
        HTTP_BODY1=$(echo "$HTTP_RESPONSE1" | sed -e 's/HTTPSTATUS\:.*//g')
        HTTP_STATUS1=$(echo "$HTTP_RESPONSE1" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
        if [ "$HTTP_STATUS1" != "200" ]; then
            echo "tca_poll_policy: Retrieving app config only failed with status $HTTP_STATUS1"
            return
        fi

        URL2="$URL1:preferences"
        echo "tca_poll_policy: Retrieving app preferences only at ${URL2}"
        HTTP_RESPONSE2=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" "$URL2")
        HTTP_BODY2=$(echo "$HTTP_RESPONSE2" | sed -e 's/HTTPSTATUS\:.*//g')
        HTTP_STATUS2=$(echo "$HTTP_RESPONSE2" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
        if [ "$HTTP_STATUS2" != "200" ]; then
            echo "tca_poll_policy: Retrieving app preferences only failed with status $HTTP_STATUS2"
            return
        fi
  
        if [[ "$CONFIG" == "null"  || "$PREF" == "null" ]]; then
            echo "tca_poll_policy: either app config or app preferences being empty, config not applicable"
            return
        fi

        echo "$HTTP_BODY1" | jq . --sort-keys > "${TCA_CONF_TEMP}"
        echo "$HTTP_BODY2" | jq . --sort-keys > "${TCA_PREF_TEMP}"
    else
        CONFIG=$(echo "$HTTP_BODY" | jq .config.app_config)
        PREF=$(echo "$HTTP_BODY" | jq .config.app_preferences)
        POLICY=$(echo "$HTTP_BODY" | jq .policies.items[0].config.content.tca_policy)


        if [[ "$CONFIG" == "null"  || "$PREF" == "null" ]]; then
            echo "tca_poll_policy: CONFIG received is parsed to be empty, trying to parse using R1 format" 
            CONFIG=$(echo "$HTTP_BODY" | jq .config)
            NEWPREF=$(echo "$HTTP_BODY" | jq .preferences)

            #echo "CONFIG is [$CONFIG]"
            #echo "NEWPREF is [$NEWPREF]"
        else
            echo "tca_poll_policy: CONFIG is [${CONFIG}], PREF is [${PREF}], POLICY is [${POLICY}]"
	    ## Check if policy content under tca_policy is returned null
	    ## null indicates no active policy flow; hence use configuration loaded 
	    ## from blueprint
            if [ "$POLICY" == "null" ]; then
                # tca_policy through blueprint
                NEWPREF=${PREF}
            else
                # tca_policy through active policy flow through PH
                NEWPREF=$(echo "$PREF" | jq --arg tca_policy "$POLICY" '. + {$tca_policy}')
            fi
            NEWPREF=$(echo "$NEWPREF" | sed 's/\\n//g') 
        fi
       
        if [[ "$CONFIG" == "null"  || "$NEWPREF" == "null" ]]; then
             echo "tca_poll_policy: either app config or app preferences being empty, config not applicable"
             return
        fi

        echo "$CONFIG" | jq . --sort-keys > "${TCA_CONF_TEMP}"
        echo "$NEWPREF" | jq . --sort-keys > "${TCA_PREF_TEMP}"
    fi

    if [ ! -e "${TCA_CONF_TEMP}" ] || [ "$(ls -sh ${TCA_CONF_TEMP} |cut -f1 -d' ' |sed -e 's/[^0-9]//g')"  -lt "1" ]; then
	echo "Fail to receive configuration"
	return
    fi
    if [ ! -e "${TCA_PREF_TEMP}" ] || [ "$(ls -sh ${TCA_PREF_TEMP} |cut -f1 -d' ' |sed -e 's/[^0-9]//g')"  -lt "1" ]; then
	echo "Fail to receive preferences"
	return
    fi

    CONF_CHANGED=""
    # extract only the config section from APP CONF (which has both artifact and config sections)
    jq .config --sort-keys ${TCA_APP_CONF} > ${TCA_CONF}
    if ! diff ${TCA_CONF} ${TCA_CONF_TEMP} ; then
        echo "TCA config changed"
        # generating the new app conf using current app conf's artifact section and the new downloaded config
        jq --argfile CONFVALUE ${TCA_CONF_TEMP} '.config = $CONFVALUE' <${TCA_APP_CONF} > ${TCA_APP_CONF_TEMP}

	mv ${TCA_APP_CONF_TEMP} ${TCA_APP_CONF}
        CONF_CHANGED=1
    fi

    PERF_CHANGED=""
    # update the subscriber ConsumerID, if not already unique,
    # so replicas appear as different consumers in the consumer group
    HOSTID=$(head -1 /etc/hostname | rev |cut -f1-2 -d'-' |rev)
    CONSUMERID=$(jq .subscriberConsumerId ${TCA_PREF_TEMP} |sed -e 's/\"//g')
    if ! (echo "$CONSUMERID" |grep "$HOSTID"); then
        CONSUMERID="${CONSUMERID}-${HOSTID}"
        jq --arg CID "${CONSUMERID}" '.subscriberConsumerId = $CID' < "${TCA_PREF_TEMP}" > "${TCA_PREF_TEMP}2"
        mv "${TCA_PREF_TEMP}2" "${TCA_PREF_TEMP}"
    fi 
    if ! diff ${TCA_PREF} ${TCA_PREF_TEMP} ; then
	echo "TCA preference updated"
	mv ${TCA_PREF_TEMP} ${TCA_PREF}
        PERF_CHANGED=1
    fi

    if [[ "$PERF_CHANGED" == "1" || "$CONF_CHANGED" == "1" ]]; then
        echo "Newly received configuration/preference differ from the running instance's.  reload confg"
        tca_restart
    else
        echo "Newly received configuration/preference identical from the running instance's"
    fi 
}


export PATH=${PATH}:/opt/cdap/sdk/bin


echo "Starting TCA-CDAP in standalone mode"

# starting CDAP SDK in background
cdap sdk start 

echo "CDAP Started, waiting CDAP ready on ${CDAP_HOST}:${CDAP_PORT} ..."
while ! nc -z ${CDAP_HOST} ${CDAP_PORT}; do   
  sleep 1 # wait for 1 second before check again
done

echo "Creating namespace cdap_tca_hi_lo ..."
curl -s -X PUT "http://${CDAP_HOST}:${CDAP_PORT}/v3/namespaces/cdap_tca_hi_lo"

# stop programs
tca_stop
# delete application
tca_delete
# load artifact
tca_load_artifact
tca_load_conf
# start programs
tca_start

# get status of programs
tca_status

echo "TCA-CDAP standalone mode initialization completed, with $WORKER_COUNT / 3 up"



#Changing to HOSTNAME parameter for consistency with k8s deploy
MY_NAME=${HOSTNAME:-tca}

unset CBS_HOST
unset CBS_PORT
echo "TCA environment: I am ${MY_NAME}, consul at ${CONSUL_HOST}:${CONSUL_PORT}, CBS service name ${CBS_SERVICE_NAME}"

while echo
do
    echo "======================================================> $(date)"
    tca_status

    while [ "$WORKER_COUNT" != "3" ]; do
        echo "Status checking: worker count is $WORKER_COUNT, needs a reset"
        sleep 5

        tca_restart
        echo "TCA restarted"
    done


    if [[ -z "$CBS_HOST" ||  -z "$CBS_PORT" ]]; then
       echo "Retrieving host and port for ${CBS_SERVICE_NAME} from ${CONSUL_HOST}:${CONSUL_PORT}"
       sleep 2
       CBS_HOST=$(curl -s "${CONSUL_HOST}:${CONSUL_PORT}/v1/catalog/service/${CBS_SERVICE_NAME}" |jq .[0].ServiceAddress |sed -e 's/\"//g')
       CBS_PORT=$(curl -s "${CONSUL_HOST}:${CONSUL_PORT}/v1/catalog/service/${CBS_SERVICE_NAME}" |jq .[0].ServicePort |sed -e 's/\"//g')
       echo "CBS discovered to be at ${CBS_HOST}:${CBS_PORT}"
    fi

    if [ ! -z "$CBS_HOST" ] && [ ! -z "$CBS_PORT" ]; then
       tca_poll_policy
    fi
    sleep 30
done
