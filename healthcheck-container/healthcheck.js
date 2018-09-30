/*
Copyright(c) 2018 AT&T Intellectual Property. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.

You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
*/

//Expect ONAP and DCAE namespaces and Helm "release" name to be passed via environment variables
// 
const ONAP_NS = process.env.ONAP_NAMESPACE || 'default';
const DCAE_NS = process.env.DCAE_NAMESPACE || process.env.ONAP_NAMESPACE || 'default';
const HELM_REL = process.env.HELM_RELEASE || '';

const HEALTHY = 200;
const UNHEALTHY = 500;
const UNKNOWN = 503;

// List of deployments expected to be created via Helm
const helmDeps = 
	[
		'dcae-cloudify-manager'
	];

// List of deployments expected to be created via Cloudify Manager
const dcaeDeps  = 
	[
		'dep-config-binding-service',
		'dep-deployment-handler',
		'dep-inventory',
		'dep-service-change-handler',
		'dep-policy-handler',
		'dep-dcae-ves-collector',
		'dep-dcae-tca-analytics',
		'dep-dcae-prh',
		'dep-dcae-hv-ves-collector',
		'dep-dcae-datafile-collector'
	];

const status = require('./get-status');
const http = require('http');

// Helm deployments are always in the ONAP namespace and prefixed by Helm release name
const helmList = helmDeps.map(function(name) {
	return {namespace: ONAP_NS, deployment: HELM_REL.length > 0 ? HELM_REL + '-' + name : name};
});

// DCAE deployments via CM don't have a release prefix and are in the DCAE namespace,
// which can be the same as the ONAP namespace
const dcaeList = dcaeDeps.map(function(name) {
	return {namespace: DCAE_NS, deployment: name};
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
	
	status.getStatusListPromise(helmList.concat(dcaeList))
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
server.listen(80);
