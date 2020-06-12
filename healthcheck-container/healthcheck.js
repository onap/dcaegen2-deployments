/*
Copyright(c) 2018-2020 AT&T Intellectual Property. All rights reserved.

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

const EXPECTED_COMPONENTS='/opt/app/expected-components.json'

const fs = require('fs');

// List of deployments expected to be created via Helm
let helmDeps = [];
try {
    helmDeps = JSON.parse(fs.readFileSync(EXPECTED_COMPONENTS, {encoding: 'utf8'}));
}
catch (error) {
    console.log(`Could not access ${EXPECTED_COMPONENTS}: ${error}`);
    console.log ('Using empty list of expected components');
}

const status = require('./get-status');
const http = require('http');

// Helm deployments are always in the ONAP namespace and prefixed by Helm release name
const helmList = helmDeps.map(function(name) {
    return {namespace: ONAP_NS, deployment: HELM_REL.length > 0 ? HELM_REL + '-' + name : name};
});

const isHealthy = function(summary) {
    // Current healthiness criterion is simple--all deployments are ready
    return summary.hasOwnProperty('count') && summary.hasOwnProperty('ready') && summary.count === summary.ready;
};

const checkHealth = function (callback) {
    // Makes queries to Kubernetes and checks results
    // If we encounter some kind of error contacting k8s (or other), health status is UNKNOWN (500)
    // If we get responses from k8s but don't find all deployments ready, health status is UNHEALTHY (503)
    // If we get responses from k8s and all deployments are ready, health status is HEALTHY (200)
    // This could be a lot more nuanced, but what's here should be sufficient for R2 OOM healthchecking

    // Query k8s to find all the deployments with specified DEPLOY_LABEL
    status.getLabeledDeploymentsPromise(DCAE_NS, DEPLOY_LABEL)
    .then(function(fullDCAEList) {
        // Now get status for Helm deployments and CM deployments
        return status.getStatusListPromise(helmList.concat(fullDCAEList));
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
