#!/bin/bash

#############################################################################
#
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#############################################################################



# We now register services that are not handled by Registrator
# minimum platform components
HOSTNAME_CONSUL="consul"
SRVCNAME_CONSUL="consul"
HOSTNAME_CM="cloudify-manager"
SRVCNAME_CM="cloudify_manager"
HOSTNAME_CBS="config-binding-service"
SRVCNAME_CBS="config_binding_service"

# R2 MVP service components
HOSTNAME_MVP_VES="mvp-dcaegen2-collectors-ves"
SRVCNAME_MVP_VES="mvp-dcaegen2-collectors-ves"
HOSTNAME_MVP_TCA="mvp-dcaegen2-analytics-tca"
SRVCNAME_MVP_TCA="mvp-dcaegen2-analytics-tca"
HOSTNAME_MVP_HR="mvp-dcaegen2-analytics-holmes-rule-management"
SRVCNAME_MVP_HR="mvp-dcaegen2-analytics-holmes-rule-management"
HOSTNAME_MVP_HE="mvp-dcaegen2-analytics-holmes-engine-management"
SRVCNAME_MVP_HE="mvp-dcaegen2-analytics-holmes-engine-management"

# R2 PLUS service components
HOSTNAME_STATIC_SNMPTRAP="static-dcaegen2-collectors-snmptrap"
SRVCNAME_STATIC_SNMPTRAP="static-dcaegen2-collectors-snmptrap"
HOSTNAME_STATIC_MAPPER="static-dcaegen2-services-mapper"
SRVCNAME_STATIC_MAPPER="static-dcaegen2-services-mapper"
HOSTNAME_STATIC_HEARTBEAT="static-dcaegen2-services-heartbeat"
SRVCNAME_STATIC_HEARTBEAT="static-dcaegen2-services-heartbeat"
HOSTNAME_STATIC_PRH="static-dcaegen2-services-prh"
SRVCNAME_STATIC_PRH="static-dcaegen2-services-prh"


# registering docker host
SVC_NAME="dockerhost"
SVC_IP="$(cat /opt/config/dcae_ip_addr.txt)"
REGREQ="
{
  \"Name\" : \"${SVC_NAME}\",
  \"ID\" : \"${SVC_NAME}\",
  \"Address\": \"${SVC_IP}\",
  \"Port\": 2376,
  \"Check\" : {
    \"Name\" : \"${SVC_NAME}_health\",
    \"Interval\" : \"15s\",
    \"HTTP\" : \"http://${SVC_IP}:2376/containers/registrator/json\",
    \"Status\" : \"passing\"
  }
}
"
curl -v -X PUT -H 'Content-Type: application/json' \
--data-binary "$REGREQ" \
"http://${HOSTNAME_CONSUL}:8500/v1/agent/service/register"

#Add KV for dockerplugin login
REGREQ="
[
	{ 
		\"username\": \"docker\", 
		\"password\": \"docker\", 
		\"registry\": \"nexus3.onap.org:10001\" 
	}
]
"
curl -v -X PUT -H 'Content-Type: application/json' \
--data-binary "$REGREQ" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/docker_plugin/docker_logins"



# registering Holmes services
SVC_NAME="${SRVCNAME_MVP_HR}"
SVC_IP="$(cat /opt/config/dcae_ip_addr.txt)"
REGREQ="
{
  \"Name\" : \"${SVC_NAME}\",
  \"ID\" : \"${SVC_NAME}\",
  \"Address\": \"${SVC_IP}\",
  \"Port\": 9101,
  \"Check\" : {
    \"Name\" : \"${SVC_NAME}_health\",
    \"Interval\" : \"15s\",
    \"HTTP\" : \"https://${SVC_IP}:9101/api/holmes-rule-mgmt/v1/healthcheck\",
    \"tls_skip_verify\": true,
    \"Status\" : \"passing\"
  }
}
"
curl -v -X PUT -H 'Content-Type: application/json' \
--data-binary \
"$REGREQ" "http://${HOSTNAME_CONSUL}:8500/v1/agent/service/register"


SVC_NAME="${SRVCNAME_MVP_HE}"
SVC_IP="$(cat /opt/config/dcae_ip_addr.txt)"
REGREQ="
{
  \"Name\" : \"${SVC_NAME}\",
  \"ID\" : \"${SVC_NAME}\",
  \"Address\": \"${SVC_IP}\",
  \"Port\": 9102,
  \"Check\" : {
    \"Name\" : \"${SVC_NAME}_health\",
    \"Interval\" : \"15s\",
    \"HTTP\" : \"https://${SVC_IP}:9102/api/holmes-engine-mgmt/v1/healthcheck\",
    \"tls_skip_verify\": true,
    \"Status\" : \"passing\"
  }
}
"
curl -v -X PUT -H 'Content-Type: application/json' \
--data-binary "$REGREQ" \
"http://${HOSTNAME_CONSUL}:8500/v1/agent/service/register"



# now push KVs
# generated with https://www.browserling.com/tools/json-escape
# config binding service
REGKV="
{}
"
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
http://${HOSTNAME_CONSUL}:8500/v1/kv/config_binding_service
# checked



# inventory
REGKV='
{
  "database": {
    "checkConnectionWhileIdle": false,
    "driverClass": "org.postgresql.Driver",
    "evictionInterval": "10s",
    "initialSize": 2,
    "maxSize": 8,
    "maxWaitForConnection": "1s",
    "minIdleTime": "1 minute",
    "minSize": 2,
    "password": "inventorypwd",
    "properties": {
      "charSet": "UTF-8"},
      "url": "jdbc:postgresql://pgInventory:5432/postgres",
      "user": "inventory",
      "validationQuery": "/* MyService Health Check */ SELECT 1"
    },
    "databusControllerConnection": {
      "host": "databus-controller-hostname",
      "mechId": null,
      "password": null,
      "port": 8443,
      "required": false},
      "httpClient": {
        "connectionTimeout": "5000milliseconds",
        "gzipEnabled": false,
        "gzipEnabledForRequests": false,
        "maxThreads": 128,
        "minThreads": 1,
        "timeout": "5000milliseconds"
      }
    }
  }
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
http://${HOSTNAME_CONSUL}:8500/v1/kv/inventory
# checked


# policy handler
REGKV='
{
  "policy_handler": {
    "deploy_handler": "deployment_handler",
    "thread_pool_size": 4,
    "policy_retry_count": 5,
    "scope_prefixes": ["DCAE.Config_","CLAMP"],
    "pool_connections": 20,
    "policy_retry_sleep": 5,
    "policy_engine": {
      "path_api": "/pdp/api/",
      "headers": {
        "Environment": "TEST",
        "ClientAuth": "cHl0aG9uOnRlc3Q=",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Basic dGVzdHBkcDphbHBoYTEyMw=="
      },
      "path_pdp": "/pdp/",
      "url": "http://{{ policy_ip_addr }}:8081",
      "target_entity": "policy_engine"
    }
  }
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/policy_handler"


# service change handler
REGKV='
{
  "asdcDistributionClient": {
    "asdcAddress": "{{ sdc_ip_addr }}:8443",
    "asdcUri": "https://{{ sdc_ip_addr }}:8443",
    "msgBusAddress": "{{ mr_ip_addr }}",
    "user": "dcae",
    "password": "Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U",
    "pollingInterval": 20,
    "pollingTimeout": 20,
    "consumerGroup": "dcae",
    "consumerId": "dcae-sch",
    "environmentName": "AUTO",
    "keyStorePath": null,
    "keyStorePassword": null,
    "activateServerTLSAuth": false,
    "useHttpsWithDmaap": false,
    "isFilterInEmptyResources": false
  },
  "dcaeInventoryClient": {
    "uri": "http://inventory:8080"
  }
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/service-change-handler"


# deployment handler
REGKV='
{
  "logLevel": "DEBUG",
  "cloudify": {
    "protocol": "http"
  },
  "inventory": {
    "protocol": "http"
  }
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/deployment_handler"


# ves
MR_IP="$(cat /opt/config/mr_ip_addr.txt)"
REGKV='
{
  "event.transform.flag": "0",
  "tomcat.maxthreads": "200",
  "collector.schema.checkflag": "1",
  "collector.dmaap.streamid": "fault=ves_fault|syslog=ves_syslog|heartbeat=ves_heartbeat|measurementsForVfScaling=ves_measurement|mobileFlow=ves_mobileflow|other=ves_other|stateChange=ves_statechange|thresholdCrossingAlert=ves_thresholdCrossingAlert|voiceQuality=ves_voicequality|sipSignaling=ves_sipsignaling",
  "collector.service.port": "8080",
  "collector.schema.file": "{\"v1\":\"./etc/CommonEventFormat_27.2.json\",\"v2\":\"./etc/CommonEventFormat_27.2.json\",\"v3\":\"./etc/CommonEventFormat_27.2.json\",\"v4\":\"./etc/CommonEventFormat_27.2.json\",\"v5\":\"./etc/CommonEventFormat_28.4.1.json\"}\",
  "collector.keystore.passwordfile": "/opt/app/VESCollector/etc/passwordfile",
  "collector.inputQueue.maxPending": "8096",
  "streams_publishes": {
    "ves_measurement": {
      "type": "message_router",
      "dmaap_info": {
        "topic_url": "http://{{ mr_ip_addr }}:3904/events/unauthenticated.SEC_MEASUREMENT_OUTPUT/"
      }
    }, 
    "ves_fault": {
      "type": "message_router",
      "dmaap_info": {
        "topic_url": "http://{{ mr_ip_addr }}:3904/events/unauthenticated.SEC_FAULT_OUTPUT/"
      }
    }
  },
  "collector.service.secure.port": "8443",
  "header.authflag": "0",
  "collector.keystore.file.location": "/opt/app/VESCollector/etc/keystore",
  "collector.keystore.alias": "dynamically generated",
  "services_calls": [],
  "header.authlist": "userid1,base64encodepwd1|userid2,base64encodepwd2"
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/mvp-dcaegen2-collectors-ves"


# holmes rule management
MSB_IP="$(cat /opt/config/msb_ip_addr.txt)"
REGKV="
{
  \"streams_subscribes\": {},
  \"msb.hostname\": \"${MSB_IP_ADDR}\",
  \"msb.uri\": \"/api/microservices/v1/services\",
  \"streams_publishes\": {},
  \"holmes.default.rule.volte.scenario1\": \"ControlLoop-VOLTE-2179b738-fd36-4843-a71a-a8c24c70c55b\$\$\$package org.onap.holmes.droolsRule;\\n\\nimport org.onap.holmes.common.dmaap.DmaapService;\\nimport org.onap.holmes.common.api.stat.VesAlarm;\\nimport org.onap.holmes.common.aai.CorrelationUtil;\\nimport org.onap.holmes.common.dmaap.entity.PolicyMsg;\\nimport org.onap.holmes.common.dropwizard.ioc.utils.ServiceLocatorHolder;\\nimport org.onap.holmes.common.utils.DroolsLog;\\n \\n\\nrule \\\"Relation_analysis_Rule\\\"\\nsalience 200\\nno-loop true\\n    when\\n        \$root : VesAlarm(alarmIsCleared == 0,\\n            \$sourceId: sourceId, sourceId != null && !sourceId.equals(\\\"\\\"),\\n\\t\\t\\t\$sourceName: sourceName, sourceName \!= null \&\& \!sourceName.equals(\\\"\\\"),\\n\\t\\t\\t\$startEpochMicrosec: startEpochMicrosec,\\n            eventName in (\\\"Fault_MultiCloud_VMFailure\\\"),\\n            \$eventId: eventId)\\n        \$child : VesAlarm( eventId \!= $eventId, parentId == null,\\n            CorrelationUtil.getInstance().isTopologicallyRelated(sourceId, \$sourceId, \$sourceName),\\n            eventName in (\\\"Fault_MME_eNodeB out of service alarm\\\"),\\n            startEpochMicrosec \< \$startEpochMicrosec + 60000 \&\& startEpochMicrosec \> \$startEpochMicrosec - 60000 )\\n    then\\n\\t\\tDroolsLog.printInfo(\\\"===========================================================\\\");\\n\\t\\tDroolsLog.printInfo(\\\"Relation_analysis_Rule: rootId=\\\" + \$root.getEventId() + \\\", childId=\\\" + \$child.getEventId());\\n\\t\\t\$child.setParentId(\$root.getEventId());\\n\\t\\tupdate(\$child);\\n\\t\\t\\nend\\n\\nrule \\\"root_has_child_handle_Rule\\\"\\nsalience 150\\nno-loop true\\n\\twhen\\n\\t\\t\$root : VesAlarm(alarmIsCleared == 0, rootFlag == 0, \$eventId: eventId)\\n\\t\\t\$child : VesAlarm(eventId \!= $eventId, parentId == $eventId)\\n\\tthen\\n\\t\\tDroolsLog.printInfo(\\\"===========================================================\\\");\\n\\t\\tDroolsLog.printInfo(\\\"root_has_child_handle_Rule: rootId=\\\" + \$root.getEventId() + \\\", childId=\\\" + $child.getEventId());\\n\\t\\tDmaapService dmaapService = ServiceLocatorHolder.getLocator().getService(DmaapService.class);\\n\\t\\tPolicyMsg policyMsg = dmaapService.getPolicyMsg(\$root, \$child, \\\"org.onap.holmes.droolsRule\\\");\\n        dmaapService.publishPolicyMsg(policyMsg, \\\"unauthenticated.DCAE_CL_OUTPUT\\\");\\n\\t\\t\$root.setRootFlag(1);\\n\\t\\tupdate(\$root);\\nend\\n\\nrule \\\"root_no_child_handle_Rule\\\"\\nsalience 100\\nno-loop true\\n    when\\n        \$root : VesAlarm(alarmIsCleared == 0, rootFlag == 0,\\n            sourceId \!= null \&\& \!sourceId.equals(\\\"\\\"),\\n\\t\\t\\tsourceName \!= null \&\& \!sourceName.equals(\\\"\\\"),\\n            eventName in (\\\"Fault_MultiCloud_VMFailure\\\"))\\n    then\\n\\t\\tDroolsLog.printInfo(\\\"===========================================================\\\");\\n\\t\\tDroolsLog.printInfo(\\\"root_no_child_handle_Rule: rootId=\\\" + \$root.getEventId());\\n\\t\\tDmaapService dmaapService = ServiceLocatorHolder.getLocator().getService(DmaapService.class);\\n\\t\\tPolicyMsg policyMsg = dmaapService.getPolicyMsg(\$root, null, \\\"org.onap.holmes.droolsRule\\\");\\n        dmaapService.publishPolicyMsg(policyMsg, \\\"unauthenticated.DCAE_CL_OUTPUT\\\");\\n\\t\\t$root.setRootFlag(1);\\n\\t\\tupdate(\$root);\\nend\\n\\nrule \\\"root_cleared_handle_Rule\\\"\\nsalience 100\\nno-loop true\\n    when\\n        \$root : VesAlarm(alarmIsCleared == 1, rootFlag == 1)\\n    then\\n\\t\\tDroolsLog.printInfo(\\\"===========================================================\\\");\\n\\t\\tDroolsLog.printInfo(\\\"root_cleared_handle_Rule: rootId=\\\" + \$root.getEventId());\\n\\t\\tDmaapService dmaapService = ServiceLocatorHolder.getLocator().getService(DmaapService.class);\\n\\t\\tPolicyMsg policyMsg = dmaapService.getPolicyMsg(\$root, null, \\\"org.onap.holmes.droolsRule\\\");\\n        dmaapService.publishPolicyMsg(policyMsg, \\\"unauthenticated.DCAE_CL_OUTPUT\\\");\\n\\t\\tretract(\$root);\\nend\\n\\nrule \\\"child_handle_Rule\\\"\\nsalience 100\\nno-loop true\\n    when\\n        \$child : VesAlarm(alarmIsCleared == 1, rootFlag == 0)\\n    then\\n\\t\\tDroolsLog.printInfo(\\\"===========================================================\\\");\\n\\t\\tDroolsLog.printInfo(\\\"child_handle_Rule: childId=\\\" + \$child.getEventId());\\n\\t\\tretract(\$child);\\nend\", 
  \"services_calls\": {}
}"



REGKV='
{
  "streams_subscribes": {},
  "msb.hostname": "{{ msb_ip_addr }}",
  "msb.uri": "/api/microservices/v1/services",
  "streams_publishes": {},
  "holmes.default.rule.volte.scenario1": "ControlLoop-VOLTE-2179b738-fd36-4843-a71a-a8c24c70c55b$$$package org.onap.holmes.droolsRule;\n\nimport org.onap.holmes.common.dmaap.DmaapService;\nimport org.onap.holmes.common.api.stat.VesAlarm;\nimport org.onap.holmes.common.aai.CorrelationUtil;\nimport org.onap.holmes.common.dmaap.entity.PolicyMsg;\nimport org.onap.holmes.common.dropwizard.ioc.utils.ServiceLocatorHolder;\nimport org.onap.holmes.common.utils.DroolsLog;\n \n\nrule \"Relation_analysis_Rule\"\nsalience 200\nno-loop true\n    when\n        $root : VesAlarm(alarmIsCleared == 0,\n            $sourceId: sourceId, sourceId != null && !sourceId.equals(\"\"),\n\t\t\t$sourceName: sourceName, sourceName != null && !sourceName.equals(\"\"),\n\t\t\t$startEpochMicrosec: startEpochMicrosec,\n            eventName in (\"Fault_MultiCloud_VMFailure\"),\n            $eventId: eventId)\n        $child : VesAlarm( eventId != $eventId, parentId == null,\n            CorrelationUtil.getInstance().isTopologicallyRelated(sourceId, $sourceId, $sourceName),\n            eventName in (\"Fault_MME_eNodeB out of service alarm\"),\n            startEpochMicrosec < $startEpochMicrosec + 60000 && startEpochMicrosec > $startEpochMicrosec - 60000 )\n    then\n\t\tDroolsLog.printInfo(\"===========================================================\");\n\t\tDroolsLog.printInfo(\"Relation_analysis_Rule: rootId=\" + $root.getEventId() + \", childId=\" + $child.getEventId());\n\t\t$child.setParentId($root.getEventId());\n\t\tupdate($child);\n\t\t\nend\n\nrule \"root_has_child_handle_Rule\"\nsalience 150\nno-loop true\n\twhen\n\t\t$root : VesAlarm(alarmIsCleared == 0, rootFlag == 0, $eventId: eventId)\n\t\t$child : VesAlarm(eventId != $eventId, parentId == $eventId)\n\tthen\n\t\tDroolsLog.printInfo(\"===========================================================\");\n\t\tDroolsLog.printInfo(\"root_has_child_handle_Rule: rootId=\" + $root.getEventId() + \", childId=\" + $child.getEventId());\n\t\tDmaapService dmaapService = ServiceLocatorHolder.getLocator().getService(DmaapService.class);\n\t\tPolicyMsg policyMsg = dmaapService.getPolicyMsg($root, $child, \"org.onap.holmes.droolsRule\");\n        dmaapService.publishPolicyMsg(policyMsg, \"unauthenticated.DCAE_CL_OUTPUT\");\n\t\t$root.setRootFlag(1);\n\t\tupdate($root);\nend\n\nrule \"root_no_child_handle_Rule\"\nsalience 100\nno-loop true\n    when\n        $root : VesAlarm(alarmIsCleared == 0, rootFlag == 0,\n            sourceId != null && !sourceId.equals(\"\"),\n\t\t\tsourceName != null && !sourceName.equals(\"\"),\n            eventName in (\"Fault_MultiCloud_VMFailure\"))\n    then\n\t\tDroolsLog.printInfo(\"===========================================================\");\n\t\tDroolsLog.printInfo(\"root_no_child_handle_Rule: rootId=\" + $root.getEventId());\n\t\tDmaapService dmaapService = ServiceLocatorHolder.getLocator().getService(DmaapService.class);\n\t\tPolicyMsg policyMsg = dmaapService.getPolicyMsg($root, null, \"org.onap.holmes.droolsRule\");\n        dmaapService.publishPolicyMsg(policyMsg, \"unauthenticated.DCAE_CL_OUTPUT\");\n\t\t$root.setRootFlag(1);\n\t\tupdate($root);\nend\n\nrule \"root_cleared_handle_Rule\"\nsalience 100\nno-loop true\n    when\n        $root : VesAlarm(alarmIsCleared == 1, rootFlag == 1)\n    then\n\t\tDroolsLog.printInfo(\"===========================================================\");\n\t\tDroolsLog.printInfo(\"root_cleared_handle_Rule: rootId=\" + $root.getEventId());\n\t\tDmaapService dmaapService = ServiceLocatorHolder.getLocator().getService(DmaapService.class);\n\t\tPolicyMsg policyMsg = dmaapService.getPolicyMsg($root, null, \"org.onap.holmes.droolsRule\");\n        dmaapService.publishPolicyMsg(policyMsg, \"unauthenticated.DCAE_CL_OUTPUT\");\n\t\tretract($root);\nend\n\nrule \"child_handle_Rule\"\nsalience 100\nno-loop true\n    when\n        $child : VesAlarm(alarmIsCleared == 1, rootFlag == 0)\n    then\n\t\tDroolsLog.printInfo(\"===========================================================\");\n\t\tDroolsLog.printInfo(\"child_handle_Rule: childId=\" + $child.getEventId());\n\t\tretract($child);\nend", 
  "services_calls": {}
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/mvp-dcae-analytics-holmes-rule-management"



# Holmes engine management
REGKV='
{
  "msb.hostname": "10.0.14.1",
  "services_calls": {},
  "msb.uri": "/api/microservices/v1/services",
  "streams_publishes": {
    "dcae_cl_out": {
      "type": "message_router",
      "dmaap_info": {
        "topic_url": "http://{{ mr_ip_addr }}:3904/events/unauthenticated.DCAE_CL_OUTPUT"
      }
    }
  },
  "streams_subscribes": {
    "ves_fault": {
      "type": "message_router",
      "dmaap_info": {
        "topic_url": "http://{{ mr_ip_addr }}:3904/events/unauthenticated.SEC_FAULT_OUTPUT"
      }
    }
  }
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/mvp-dcae-analytics-holmes-engine-management"


#curl  http://localhost:8500/v1/kv/config_binding_service |jq .[0].Value |sed -e 's/\"//g' |base64 --decode



# TCA
REGKV='
{
  "thresholdCalculatorFlowletInstances": "2",
  "tcaVESMessageStatusTableTTLSeconds": "86400",
  "tcaVESMessageStatusTableName": "TCAVESMessageStatusTable",
  "tcaVESAlertsTableTTLSeconds": "1728000",
  "tcaVESAlertsTableName": "TCAVESAlertsTable",
  "tcaSubscriberOutputStreamName": "TCASubscriberOutputStream",
  "tcaAlertsAbatementTableTTLSeconds": "1728000",
  "tcaAlertsAbatementTableName": "TCAAlertsAbatementTable",
  "streams_subscribes": {},
  "streams_publishes": {},
  "services_calls": {},
  "appName": "dcae-tca", 
  "appDescription": "DCAE Analytics Threshold Crossing Alert Application"
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/mvp-dcaegen2-analytics-tca"


# TCA pref
REGKV='{
  "tca_policy": "{\"domain\":\"measurementsForVfScaling\",\"metricsPerEventName\":[{\"eventName\":\"vFirewallBroadcastPackets\",\"controlLoopSchemaType\":\"VNF\",\"policyScope\":\"DCAE\",\"policyName\":\"DCAE.Config_tca-hi-lo\",\"policyVersion\":\"v0.0.1\",\"thresholds\":[{\"closedLoopControlName\":\"ControlLoop-vFirewall-d0a1dfc6-94f5-4fd4-a5b5-4630b438850a\",\"version\":\"1.0.2\",\"fieldPath\":\"$.event.measurementsForVfScalingFields.vNicUsageArray[*].receivedTotalPacketsDelta\",\"thresholdValue\":300,\"direction\":\"LESS_OR_EQUAL\",\"severity\":\"MAJOR\",\"closedLoopEventStatus\":\"ONSET\"},{\"closedLoopControlName\":\"ControlLoop-vFirewall-d0a1dfc6-94f5-4fd4-a5b5-4630b438850a\",\"version\":\"1.0.2\",\"fieldPath\":\"$.event.measurementsForVfScalingFields.vNicUsageArray[*].receivedTotalPacketsDelta\",\"thresholdValue\":700,\"direction\":\"GREATER_OR_EQUAL\",\"severity\":\"CRITICAL\",\"closedLoopEventStatus\":\"ONSET\"}]},{\"eventName\":\"vLoadBalancer\",\"controlLoopSchemaType\":\"VM\",\"policyScope\":\"DCAE\",\"policyName\":\"DCAE.Config_tca-hi-lo\",\"policyVersion\":\"v0.0.1\",\"thresholds\":[{\"closedLoopControlName\":\"ControlLoop-vDNS-6f37f56d-a87d-4b85-b6a9-cc953cf779b3\",\"version\":\"1.0.2\",\"fieldPath\":\"$.event.measurementsForVfScalingFields.vNicUsageArray[*].receivedTotalPacketsDelta\",\"thresholdValue\":300,\"direction\":\"GREATER_OR_EQUAL\",\"severity\":\"CRITICAL\",\"closedLoopEventStatus\":\"ONSET\"}]},{\"eventName\":\"Measurement_vGMUX\",\"controlLoopSchemaType\":\"VNF\",\"policyScope\":\"DCAE\",\"policyName\":\"DCAE.Config_tca-hi-lo\",\"policyVersion\":\"v0.0.1\",\"thresholds\":[{\"closedLoopControlName\":\"ControlLoop-vCPE-48f0c2c3-a172-4192-9ae3-052274181b6e\",\"version\":\"1.0.2\",\"fieldPath\":\"$.event.measurementsForVfScalingFields.additionalMeasurements[*].arrayOfFields[0].value\",\"thresholdValue\":0,\"direction\":\"EQUAL\",\"severity\":\"MAJOR\",\"closedLoopEventStatus\":\"ABATED\"},{\"closedLoopControlName\":\"ControlLoop-vCPE-48f0c2c3-a172-4192-9ae3-052274181b6e\",\"version\":\"1.0.2\",\"fieldPath\":\"$.event.measurementsForVfScalingFields.additionalMeasurements[*].arrayOfFields[0].value\",\"thresholdValue\":0,\"direction\":\"GREATER\",\"severity\":\"CRITICAL\",\"closedLoopEventStatus\":\"ONSET\"}]}]}",
  "subscriberTopicName": "unauthenticated.SEC_MEASUREMENT_OUTPUT",
  "subscriberTimeoutMS": "-1",
  "subscriberProtocol": "http",
  "subscriberPollingInterval": "30000",
  "subscriberMessageLimit": "-1",
  "subscriberHostPort": "3904",
  "subscriberHostName":"{{ mr_ip_addr }}",
  "subscriberContentType": "application/json",
  "subscriberConsumerId": "c12",
  "subscriberConsumerGroup": "OpenDCAE-c12",
  "publisherTopicName": "unauthenticated.DCAE_CL_OUTPUT",
  "publisherProtocol": "http",
  "publisherPollingInterval": "20000",
  "publisherMaxRecoveryQueueSize": "100000",
  "publisherMaxBatchSize": "1",
  "publisherHostPort": "3904",
  "publisherHostName": "{{ mr_ip_addr }}",
  "publisherContentType": "application/json",
  "enableAlertCEFFormat": "false",
  "enableAAIEnrichment": true,
  "aaiVNFEnrichmentAPIPath": "/aai/v11/network/generic-vnfs/generic-vnf",
  "aaiVMEnrichmentAPIPath": "/aai/v11/search/nodes-query",
  "aaiEnrichmentUserPassword": "DCAE",
  "aaiEnrichmentUserName": "DCAE",
  "aaiEnrichmentProtocol": "https",
  "aaiEnrichmentPortNumber": "8443",
  "aaiEnrichmentIgnoreSSLCertificateErrors": "true",
  "aaiEnrichmentHost":"{{ aai1_ip_addr }}",
  "enableRedisCaching":false
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/mvp-dcaegen2-analytics-tca:preferences"



# SNMP Trap Collector
REGKV='{
"snmptrap.version": "1.3.0",
"snmptrap.title": "ONAP SNMP Trap Receiver" ,
"protocols.transport": "udp",
"protocols.ipv4_interface": "0.0.0.0",
"protocols.ipv4_port": 6162,
"protocols.ipv6_interface": "::1",
"protocols.ipv6_port": 6162,
"cache.dns_cache_ttl_seconds": 60,
"publisher.http_timeout_milliseconds": 1500,
"publisher.http_retries": 3,
"publisher.http_milliseconds_between_retries": 750,
"publisher.http_primary_publisher": "true",
"publisher.http_peer_publisher": "unavailable",
"publisher.max_traps_between_publishes": 10,
"publisher.max_milliseconds_between_publishes": 10000,
    "streams_publishes": {
            "sec_measurement": {
                "aaf_password": "aaf_password",
                "dmaap_info": {
                    "location": "mtl5",
                    "client_id": "111111",
                    "client_role": "com.att.dcae.member",
                    "topic_url": null
                },
                "aaf_username": "aaf_username"
            },
            "sec_fault_unsecure": {
                "type": "message_router",
                "aaf_password": null,
                "dmaap_info": {
                    "location": "mtl5",
                    "client_id": null,
                    "client_role": null,
                    "topic_url": "http://{{ mr_ip_addr }}:3904/events/ONAP-COLLECTOR-SNMPTRAP"
                },
                "aaf_username": null
            }
    },
"files.runtime_base_dir": "/opt/app/snmptrap",
"files.log_dir": "logs",
"files.data_dir": "data",
"files.pid_dir": "tmp",
"files.arriving_traps_log": "snmptrapd_arriving_traps.log",
"files.snmptrapd_diag": "snmptrapd_prog_diag.log",
"files.traps_stats_log": "snmptrapd_stats.csv",
"files.perm_status_file": "snmptrapd_status.log",
"files.eelf_base_dir": "/opt/app/snmptrap/logs",
"files.eelf_error": "error.log",
"files.eelf_debug": "debug.log",
"files.eelf_audit": "audit.log",
"files.eelf_metrics": "metrics.log",
"files.roll_frequency": "hour",
"files.minimum_severity_to_log": 1,
"trap_def.1.trap_oid" : ".1.3.6.1.4.1.74.2.46.12.1.1",
"trap_def.1.trap_category": "ONAP-COLLECTOR-SNMPTRAP",
"trap_def.2.trap_oid" : "*",
"trap_def.2.trap_category": "ONAP-COLLECTOR-SNMPTRAP",
"stormwatch.1.stormwatch_oid" : ".1.3.6.1.4.1.74.2.46.12.1.1",
"stormwatch.1.low_water_rearm_per_minute" : "5",
"stormwatch.1.high_water_arm_per_minute" : "100",
"stormwatch.2.stormwatch_oid" : ".1.3.6.1.4.1.74.2.46.12.1.2",
"stormwatch.2.low_water_rearm_per_minute" : "2",
"stormwatch.2.high_water_arm_per_minute" : "200",
"stormwatch.3.stormwatch_oid" : ".1.3.6.1.4.1.74.2.46.12.1.2",
"stormwatch.3.low_water_rearm_per_minute" : "2",
"stormwatch.3.high_water_arm_per_minute" : "200"
}'
curl -v -X PUT -H "Content-Type: application/json" \
--data "${REGKV}" \
"http://${HOSTNAME_CONSUL}:8500/v1/kv/${SRVCNAME_STATIC_SNMPTRAP}"

