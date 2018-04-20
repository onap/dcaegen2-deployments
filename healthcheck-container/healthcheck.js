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
const DCAE_NS = process.env.DCAE_NAMESPACE || 'default';
const HELM_REL = process.env.HELM_RELEASE || '';

const HEALTHY = 200;
const UNHEALTHY = 500;
const UNKNOWN = 503;

const status = require('./get-status');
const http = require('http');

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
	status.getStatusNamespace(DCAE_NS, function(err, res, body) {
		let ret = {status : UNKNOWN, body: [body]};
		if (err) {
			callback(ret);
		}
		else if (body.type && body.type === 'summary') {
			if (isHealthy(body)) {
				// All the DCAE components report healthy -- check Cloudify Manager
				let cmDeployment = 'dcae-cloudify-manager';
				if (HELM_REL.length > 0) {
					cmDeployment = HELM_REL + '-' + cmDeployment;
				}
				status.getStatusSingle(ONAP_NS, cmDeployment, function (err, res, body){
					ret.body.push(body);
					if (err) {
						callback(ret);
					}
					if (body.type && body.type === 'summary') {
						ret.status = isHealthy(body) ? HEALTHY : UNHEALTHY;
					}
					callback(ret);
				});
			}
			else {
				callback(ret);
			}
		}
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
