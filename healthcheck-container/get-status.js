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
const request = require('request');

const K8S_CREDS = '/var/run/secrets/kubernetes.io/serviceaccount';
const K8S_API = 'https://kubernetes.default.svc.cluster.local/';	// Full name to match cert for TLS
const K8S_PATH = 'apis/apps/v1beta2/namespaces/';

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
	// Make request to Kubernetes
	
	const options = {
		url: K8S_API + path,
		ca : ca,
		headers: {
			Authorization: 'bearer ' + token
		},
		json: true
	};
	console.log ("request url: " + options.url);
	request(options, function(error, res, body) {
		console.log ("status: " + (res && res.statusCode) ? res.statusCode : "NONE");
		if (error) {
			console.log("error: " + error);
		}
		callback(error, res, body);
	});
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