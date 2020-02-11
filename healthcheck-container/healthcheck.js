/*
Copyright(c) 2018-2019 AT&T Intellectual Property. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.

You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
*/

// Expect ONAP and DCAE namespaces and Helm "release" name to be passed via environment variables
const ONAP_NS = process.env.ONAP_NAMESPACE || 'default';
const DCAE_NS = process.env.DCAE_NAMESPACE || process.env.ONAP_NAMESPACE || 'default';
const HELM_REL = process.env.HELM_RELEASE || '';

const HEALTHY = 200;
const UNHEALTHY = 500;
const UNKNOWN = 503;

// List of deployments expected to be created via Helm
const helmDeps =
    [
        'dcae-cloudify-manager',
        'dcae-config-binding-service',
        'dcae-inventory-api',
        'dcae-servicechange-handler',
        'dcae-deployment-handler',
        'dcae-policy-handler',
        'dcae-dashboard'
    ];

// List of deployments expected to be created by CM at boot time
const bootDeps =
    [
        'dep-dcae-ves-collector',
        'dep-dcae-tca-analytics',
        'dep-dcae-prh',
        'dep-dcae-hv-ves-collector'
    ];

const status = require('./get-status');
const http = require('http');

// Helm deployments are always in the ONAP namespace and prefixed by Helm release name
const helmList = helmDeps.map(function(name) {
    return {namespace: ONAP_NS, deployment: HELM_REL.length > 0 ? HELM_REL + '-' + name : name};
});

const isHealthy = function(summary) {
    // Current healthiness criterion is simple--all deployments are ready
    return summary.count && summary.ready && summary.count === summary.ready;
};

const checkHealth = function (callback) {
    // Makes queries to Kubernetes and checks results
    // If we encounter some kind of error contacting k8s (or other), health status is UNKNOWN (500)
    // If we get responses from k8s but don't find all deployments ready, health status is UNHEALTHY (503)
    // If we get responses from k8s and all deployments are ready, health status is HEALTHY (200)
    // This could be a lot more nuanced, but what's here should be sufficient for R2 OOM healthchecking

    // Query k8s to find all the deployments launched by CM (they all have a 'cfydeployment' label)
    status.getDCAEDeploymentsPromise(DCAE_NS)
    .then(function(fullDCAEList) {
        // Remove any expected boot-time CM deployments from the list to avoid duplicates
        dynamicDCAEDeps = fullDCAEList.filter(function(i) {return !(bootDeps.includes(i.deployment));})
        // Create full list of CM deployments to check: boot deployments and anything else created by CM
        dcaeList = (bootDeps.map(function(name){return {namespace: DCAE_NS, deployment: name}})).concat(dynamicDCAEDeps);
        // Now get status for Helm deployments and CM deployments
        return status.getStatusListPromise(helmList.concat(dcaeList));
    })
    .then(function(body) {
        callback({status: isHealthy(body) ? HEALTHY : UNHEALTHY, body: body});
    })
    .catch(function(error){
        callback({status: UNKNOWN, body: [error]})
    });
};

// Simple HTTP server--any incoming request triggers a health check
const server = http.createServer(function(req, res) {
    checkHealth(function(ret) {
        console.log ((new Date()).toISOString() + ": " + JSON.stringify(ret));
        res.statusCode = ret.status;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(ret.body || {}), 'utf8');
    });
});
server.listen(8080);
