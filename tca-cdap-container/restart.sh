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
TCA_ARTIFACT_VERSION='2.2.0-SNAPSHOT'
TCA_FILE_PATH='/opt/tca'
TCA_JAR="${TCA_FILE_PATH}/${TCA_ARTIFACT}.${TCA_ARTIFACT_VERSION}.jar"
TCA_APP_CONF="${TCA_FILE_PATH}/tca_app_config.json"
TCA_CONF="${TCA_FILE_PATH}/tca_config.json"
TCA_PREF="${TCA_FILE_PATH}/tca_app_preferences.json"
TCA_CONF_TEMP='/tmp/tca_config.json'
TCA_APP_CONF_TEMP='/tmp/tca_app_config.json'
TCA_PREF_TEMP='/tmp/tca_preferences.json'

TCA_PATH_APP="${CDAP_HOST}:${CDAP_PORT}/v3/namespaces/${TCA_NAMESPACE}/apps/${TCA_APPNAME}"
TCA_PATH_ARTIFACT="${CDAP_HOST}:${CDAP_PORT}/v3/namespaces/${TCA_NAMESPACE}/artifacts"


CONSUL_HOST=${CONSU_HOST:-consul}
CONSUL_PORT=${CONSU_PORT:-8500}
CONFIG_BINDING_SERVICE=${CONFIG_BINDING_SERVICE:-config_binding_service}

CBS_SERVICE_NAME=${CONFIG_BINDING_SERVICE}

CBS_HOST=$(curl -s "${CONSUL_HOST}:${CONSUL_PORT}/v1/catalog/service/${CBS_SERVICE_NAME}" |jq .[0].ServiceAddress |sed -e 's/\"//g')
CBS_PORT=$(curl -s "${CONSUL_HOST}:${CONSUL_PORT}/v1/catalog/service/${CBS_SERVICE_NAME}" |jq .[0].ServicePort |sed -e 's/\"//g')
CBS_HOST=${CBS_HOST:-config_binding_service}
CBS_PORT=${CBS_PORT:-10000}

MY_NAME=${SERVICE_NAME:-tca}

echo "TCA environment: I am ${MY_NAME}, consul at ${CONSUL_HOST}:${CONSUL_PORT}, CBS at ${CBS_HOST}:${CBS_PORT}, service name ${CBS_SERVICE_NAME}"


echo "Generting preference file"
sed -i 's/{{DMAAPHOST}}/'"${DMAAPHOST}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPPORT}}/'"${DMAAPPORT}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPPUBTOPIC}}/'"${DMAAPPUBTOPIC}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPSUBTOPIC}}/'"${DMAAPSUBTOPIC}"'/g' ${TCA_PREF}
sed -i 's/{{DMAAPSUBGROUP}}/OpenDCAEc12/g' ${TCA_PREF}
sed -i 's/{{DMAAPSUBID}}/c12/g' ${TCA_PREF}
sed -i 's/{{AAIHOST}}/'"${AAIHOST}"'/g' ${TCA_PREF}
sed -i 's/{{AAIPORT}}/'"${AAIPORT}"'/g' ${TCA_PREF}
if [ -z $REDISHOSTPORT ]; then
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
    echo
    echo "TCADMaaPMRPublisherWorker status: "
    curl -s "http://${TCA_PATH_APP}/workers/TCADMaaPMRPublisherWorker/status"
    echo
    echo "TCADMaaPMRSubscriberWorker status: "
    curl -s "http://${TCA_PATH_APP}/workers/TCADMaaPMRSubscriberWorker/status"
    echo
    echo "TCAVESCollectorFlow status"
    curl -s "http://${TCA_PATH_APP}/flows/TCAVESCollectorFlow/status"
    echo; echo
}


function tca_poll_policy {
    MY_NAME=${SERVICE_NAME:-tca}

    URL1="${CBS_HOST}:${CBS_PORT}/service_component/${MY_NAME}"
    URL2="$URL1:preferences"

    echo "tca_poll_policy: Retrieving configuration file at ${URL1}"
    curl -s "$URL1" | jq . --sort-keys > "${TCA_CONF_TEMP}"
    echo "Retrieving preferences file at ${URL1}"
    curl -s "$URL2" | jq . --sort-keys > "${TCA_PREF_TEMP}"

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
        jq --arg CID ${CONSUMERID} '.subscriberConsumerId = $CID' < "${TCA_PREF_TEMP}" > "${TCA_PREF_TEMP}2"
        mv "${TCA_PREF_TEMP}2" "${TCA_PREF_TEMP}"
    fi 
    if ! diff ${TCA_PREF} ${TCA_PREF_TEMP} ; then
	echo "TCA preference updated"
	mv ${TCA_PREF_TEMP} ${TCA_PREF}
        PERF_CHANGED=1
    fi

    if [[ "$PERF_CHANGED" == "1" || "$CONF_CHANGED" == "1" ]]; then 
	tca_stop
	tca_delete
        tca_load_artifact
	tca_load_conf
	tca_start
	tca_status
    fi 
}


export PATH=${PATH}:/opt/cdap/sdk/bin

# starting CDAP SDK in background
cdap sdk start 



echo "Waiting CDAP ready on port 11015 ..."
while ! nc -z ${CDAP_HOST} ${CDAP_PORT}; do   
  sleep 0.1 # wait for 1/10 of the second before check again
done
echo "CDAP has started"


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



while echo -n
do
    echo "======================================================"
    date
    tca_poll_policy
    sleep 30
done
