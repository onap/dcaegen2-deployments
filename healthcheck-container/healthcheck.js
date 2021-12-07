/*
============LICENSE_START=========================================================================
Copyright(c) 2018-2020 AT&T Intellectual Property. All rights reserved.
Copyright(c) 2021 J. F. Lucas.  All rights reserved.
==================================================================================================
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.

You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
============LICENSE_END===========================================================================
*/

// Expect ONAP and DCAE namespaces and Helm "release" name to be passed via environment variables
const ONAP_NS = process.env.ONAP_NAMESPACE || 'default';
const DCAE_NS = process.env.DCAE_NAMESPACE || process.env.ONAP_NAMESPACE || 'default';
const HELM_REL = process.env.HELM_RELEASE || '';

// If the healthcheck should include k8s deployments that are marked with a specific label,
// the DEPLOY_LABEL environment variable will be set to the name of the label.
// Note that the only the name of label is important--the value isn't used by the
// the healthcheck.  If a k8s deployment has the label, it is included in the check.
// For DCAE (dcaegen2), this capability is used to check for k8s deployments that are
// created by Cloudify using the k8s plugin.
const DEPLOY_LABEL = process.env.DEPLOY_LABEL || '';

const HEALTHY = 200;
const UNHEALTHY = 500;
const UNKNOWN = 503;

const EXPECTED_COMPONENTS = '/opt/app/expected-components.json';
const LISTEN_PORT = 8080;

const fs = require('fs');
const log = require('./log');

// List of microservices expected to be deployed automatically at DCAE installation time
let expectedMicroservices = [];
try {
    expectedMicroservices = JSON.parse(fs.readFileSync(EXPECTED_COMPONENTS, {encoding: 'utf8'}));
}
catch (error) {
    log.error(`Could not access ${EXPECTED_COMPONENTS}: ${error}`);
    log.error ('Using empty list of expected components');
}

const status = require('./get-status');
const http = require('http');

// Helm deployments are always in the ONAP namespace and prefixed by Helm release name
const expectedList = expectedMicroservices.map(function(name) {
    return {namespace: ONAP_NS, deployment: HELM_REL.length > 0 ? HELM_REL + '-' + name : name};
});

// List of deployment names for the microservices deployed automatically at DCAE installation time
const expectedDepNames = expectedList.map((d) => d.deployment);

const isHealthy = function(summary) {
    // Current healthiness criterion is simple--all deployments are ready
    return summary.hasOwnProperty('count') && summary.hasOwnProperty('ready') && summary.count === summary.ready;
};

const checkHealth = function (callback) {
    // Makes queries to Kubernetes and checks results
    // If we encounter some kind of error contacting k8s (or other), health status is UNKNOWN (503)
    // If we get responses from k8s but don't find all deployments ready, health status is UNHEALTHY (500)
    // If we get responses from k8s and all deployments are ready, health status is HEALTHY (200)
    // This could be a lot more nuanced, but what's here should be sufficient for OOM healthchecking

    // Query k8s to find all the deployments with specified DEPLOY_LABEL
    status.getLabeledDeploymentsPromise(DCAE_NS, DEPLOY_LABEL)
    .then(function(fullDCAEList) {
        // Remove expected deployments from the list
        dynamicDCAEDeps = fullDCAEList.filter( (n) => !(expectedDepNames.includes(n.deployment)) );
        // Get status for expected deployments and any dynamically deployed components
        return status.getStatusListPromise(expectedList.concat(dynamicDCAEDeps));
    })
    .then(function(body) {
        callback({status: isHealthy(body) ? HEALTHY : UNHEALTHY, body: body});
    })
    .catch(function(error){
        callback({status: UNKNOWN, body: [error]});
    });
};

// Simple HTTP server--any incoming request triggers a health check
const server = http.createServer(function(req, res) {
    checkHealth(function(ret) {
        log.info(`Incoming request: ${req.url} -- response: ${JSON.stringify(ret)}`);
        res.statusCode = ret.status;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(ret.body || {}), 'utf8');
    });
});
server.listen(LISTEN_PORT);
log.info(`Listening on port ${LISTEN_PORT} -- expected components: ${JSON.stringify(expectedMicroservices)}`);
