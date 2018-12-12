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

/*
 * Query Kubernetes for status of deployments and extract readiness information
 */

const fs = require('fs');
const https = require('https');

const K8S_CREDS = '/var/run/secrets/kubernetes.io/serviceaccount';
const K8S_HOST = 'kubernetes.default.svc.cluster.local';	// Full name to match cert for TLS
const K8S_PATH = 'apis/apps/v1beta2/namespaces/';

const CFY_LABEL = 'cfydeployment';		// All k8s deployments created by Cloudify--and only k8s deployments created by Cloudify--have this label
const MAX_DEPS = 1000;		// Maximum number of k8s deployments to return from a query to k8s

//Get token and CA cert
const ca = fs.readFileSync(K8S_CREDS + '/ca.crt');
const token = fs.readFileSync(K8S_CREDS + '/token');

const summarizeDeploymentList = function(list) {
	// list is a DeploymentList object returned by k8s
	// Individual deployments are in the array 'items'
	
	let ret = 
	{
		type: "summary",
		count: 0,
		ready: 0,
		items: []
	};
	
	// Extract readiness information
	for (let deployment of list.items) {
		ret.items.push(
			{
				name: deployment.metadata.name,
				ready: deployment.status.readyReplicas || 0,
				unavailable: deployment.status.unavailableReplicas || 0
			}
		);
		ret.count ++;
		ret.ready = ret.ready + (deployment.status.readyReplicas || 0);
	}
	
	return ret;
};

const summarizeDeployment = function(deployment) {
	// deployment is a Deployment object returned by k8s
	// we make it look enough like a DeploymentList object to
	// satisfy summarizeDeploymentList
	return summarizeDeploymentList({items: [deployment]});
};

const queryKubernetes = function(path, callback) {
	// Make GET request to Kubernetes API
	const options = {
		host: K8S_HOST,
		path: "/" + path,
		ca : ca,
		headers: {
			Authorization: 'bearer ' + token
		}
	};
	console.log ("request url: " + options.host + options.path);
	const req = https.get(options, function(resp) {
		let rawBody = "";
		resp.on("data", function(data) {
			rawBody += data;
		});
		resp.on("error", function (error) {
			console.error("error: " + error);
			callback(error, null, null)
		});
		resp.on("end", function() {
			console.log ("status: " + resp.statusCode ? resp.statusCode: "NONE")
			callback(null, resp, JSON.parse(rawBody));
		});
	});
	req.end();
};

const getStatus = function(path, extract, callback) {
	// Get info from k8s and extract readiness info
	queryKubernetes(path, function(error, res, body) {
		let ret = body;
		if (!error && res && res.statusCode === 200) {
			ret = extract(body);
		}
		callback (error, res, ret);
	});
};

const getStatusSinglePromise = function (item) {
	// Expect item to be of the form {namespace: "namespace", deployment: "deployment_name"}
	return new Promise(function(resolve, reject){
		const path = K8S_PATH + item.namespace + '/deployments/' + item.deployment;
		queryKubernetes(path, function(error, res, body){
			if (error) {
				reject(error);
			}
			else if (res.statusCode === 404) {
				// Treat absent deployment as if it's an unhealthy deployment
				resolve ({
					metadata: {name: item.deployment},
					status: {unavailableReplicas: 1}
				});
			}
			else if (res.statusCode != 200) {
				reject(body);
			}
			else {
				resolve(body);
			}
		});
	});
}
exports.getStatusNamespace = function (namespace, callback) {
	// Get readiness information for all deployments in namespace
	const path = K8S_PATH + namespace + '/deployments';
	getStatus(path, summarizeDeploymentList, callback);
};

exports.getStatusSingle = function (namespace, deployment, callback) {
	// Get readiness information for a single deployment
	const path = K8S_PATH + namespace + '/deployments/' + deployment;
	getStatus(path, summarizeDeployment, callback);
};

exports.getStatusListPromise = function (list) {
	// List is of the form [{namespace: "namespace", deployment: "deployment_name"}, ... ]
	const p = Promise.all(list.map(getStatusSinglePromise))
	return p.then(function(results) {
	    return summarizeDeploymentList({items: results});
	});
}

exports.getDCAEDeploymentsPromise = function (namespace) {
	// Return list of the form [{namespace: "namespace"}, deployment: "deployment_name"].
	// List contains all k8s deployments in the specified namespace that were deployed
	// by Cloudify, based on Cloudify's use of a "marker" label on each k8s deployment that
	// the k8s plugin created.

	return new Promise(function(resolve, reject) {
		const path = K8S_PATH + namespace + '/deployments?labelSelector=' + CFY_LABEL + '&limit=' + MAX_DEPS
		queryKubernetes(path, function(error, res, body){
			if (error) {
				reject(error);
			}
			else if (res.statusCode !== 200) {
				reject(body);
			}
			else {
				resolve(body.items.map(function(i) {return {namespace : namespace, deployment: i.metadata.name};}));
			}
		});
	});
};
