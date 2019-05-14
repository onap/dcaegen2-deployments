<!--
# Copyright (c) 2019 AT&T Intellectual Property. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
-->
# Deployment of proxy server for DCAE remote sites
_Last update: 2019-05-13_
## Background
Beginning with the ONAP Dublin release, DCAE allows for deploying data collection and analytics components into a remote site--specifically, into a Kubernetes cluster other than the central site cluster where the main ONAP and DCAE platform components are deployed.  A proxy server is deployed into each remote cluster to allow components running in the remote cluster to access DCAE platform components in the central site.   DCAE components running in a remote site can address platform components at the central site as if the platform components were running in the remote site.

A presentation describing DCAE support for remote sites in the Dublin release can be found on [the ONAP Developer Wiki](https://wiki.onap.org/download/attachments/53249727/DCAE-Multi-Site-2019-04-25.pdf).

This repository contains a Helm chart that deploys and configures a proxy server into a Kubernetes cluster and creates Kubernetes Services that route traffic through the proxy to DCAE platform components (specifically, the Consul server, the config binding service, the logstash service, the DMaaP message router server, and the DMaaP data router server).   The exact set of services and the port mappings are controlled by the `values.yaml` file in this chart.
## Prerequisites
In order to use the chart in this repo to deploy a proxy server into a remote Kubernetes cluster:

- There must a working instance of ONAP (with DCAE and other components fully deployed) on a central site Kubernetes cluster.
- There must be a working remote Kubernetes cluster, with the Helm server (`tiller`) installed on it. Nothing else should be installed on the remote cluster.
- The information needed to deploy into the remote cluster must be  available in the standard Kubernetes "kubeconfig" format.  Different installation methods provide this information in different ways.
- The person deploying this chart must have the `helm` client command line installed on a machine (the "installation machine") that can connect to the new remote cluster and has configured the `helm` client to use the cluster information for the new remote cluster.
- The person deploying this chart must have a copy of this chart, either as a file on local disk on the installation machine b or in some Helm repository.  (As of this writing, the chart is not in any public Helm repository.)
- The ONAP `common` chart, version 4.x,  must be available on a local Helm repository running on the installation machine from which the chart will be deployed.  (It is possible to change the `requirements.yaml` file to specify a different source for the `common` chart.)
- The chart's dependencies must be resolved by running `helm dep up` in the chart's directory on the local file system of the installation machine.
## Using the chart
_Note: These instructions assume that the user is familiar with deploying systems using Helm.  Users who have deployed ONAP using Helm will be familiar with these procedures.  Using Helm (and Kubernetes) with multiple clusters might be unfamiliar to some users.  These instructions assume that users rely on contexts defined in their local `kubeconfig` file to manage access to multiple Kubernetes clusters.  See [this overview](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) for more information._
### Overriding the default configuration
The `values.yaml` file delivered in this repository provides:
1. Configuration information for the proxy server itself (the image to run and the resource requirements).
2. Information about the central site services to be proxied (including the port mappings and the types of connections).
3. The routable external IP addresses of the Kubernetes hosts in the _central site_ Kubernetes cluster.  The proxy uses these addresses to route traffic from the remote cluster to the central site cluster.

The `values.yaml` file provides sensible default values for items (1) and (2) above, but for some applications there may be reasons to change them.  (For instance, it might be necessary to proxy additional central site services.  Or perhaps the external port assignments for central services are different from the standard ONAP assignments.)

The `values.yaml` file does ___not___ provide sensible defaults for item (3),the IP addresses for the central site Kubernetes nodes, because they're different for every ONAP installation.  `values.yaml` supplies a single node with the local loopback address (`127.0.0.1`), which almost certainly won't work.  It's necessary to override the default value when deploying this chart.  The property to override is `nodeAddresses`, which is an array of IP addresses or fully-qualified domain names (if containers at the remote site are configured to use a DNS server that can resolve them).  Users of this chart can either modify the `values.yaml` directly or (better) provide an override file.  For instance, for an installation where the central site cluster has three nodes at `10.10.10.100`, `10.10.10.101`, and `10.10.10.102`, an override file would look like this:
```
nodeAddresses:
  - 10.10.10.100
  - 10.10.10.101
  - 10.10.10.102
```
It's important to remember that `nodeAddresses` are the addresses of the nodes in the _central site cluster_, ___not___ the addresses of the nodes in the remote cluster being installed.  The `nodeAddresses` are used to configure the proxy so that it can reach the central cluster.  If more than one address is supplied, the proxy will distribute requests at random across the addresses.
### Deploying the proxy using the chart
The `helm install` command can be used to deploy this chart.  The exact form of the command depends on the environment.

For example, assuming:
- the chart is on local disk in a subdirectory of the current working directory, with the subdirectory named `onap-dcae-remote-site`,
- the override file containing the correct cluster node addresses is in a file called `node-addresses.yaml` in the current working directory,
- the information for accessing the remote cluster is set in the user's active `kubeconfig` under the context named `site-00`,
- the target namespace for the installation is `onap`,
- the Helm release name is `dcae-remote-00`,

then the following command would deploy the proxy into the remote site:
```
helm --kube-context site-00 install \
      -n dcae-remote-00 --namespace onap \
      -f ./node-addresses.yaml ./onap-dcae-remote-site
```

### What the chart deploys
When the chart is installed, it creates the following Kubernetes entities:
- A Kubernetes ConfigMap holding the `nginx` configuration file.  The content of the file is sourced from `resources/config/nginx.conf` in this repository.  The ConfigMap will be named _helm-release_-dcae-remote-site-proxy-configmap,
  where _helm-release_ is the Helm release name specified in the `helm install` command.

- A Kubernetes ConfigMap holding two proxy configuration files:
  - One for services using `http` connections, sourced from `resources/config/proxies/http-proxies.conf`.
  - One for services that require a simple TCP passthrough (`tcp` and `https` connections), sourced from `resources/config/proxies/stream-proxies.conf`.

  The ConfigMap will be named _helm-release_-dcae-remote-site-proxy-proxies-configmap,
  where _helm-release_ is the Helm release name specified in the `helm install` command.
- A Kubernetes Deployment, with a single Kubernetes Pod running a container with the `nginx` proxy server.  The Pod mounts the files from the ConfigMaps into the container file system at the locations expected by `nginx`. The Deployment will be named _helm-release_-dcae-remote-site-proxy,
  where _helm-release_ is the Helm release name specified in the `helm install` command.
- A Kubernetes ClusterIP Service for the `nginx` proxy.  The Service will be named `dcae-remote-site-proxy`.
- A collection of Kubernetes ClusterIP Services, one for each _service name_ listed in the `proxiedServices` array in the `values.yaml` file. (To allow for service name aliases, each proxied service can specify an array of service names.  In the default set of services in `values.yaml`, consul has two names: `consul` and `consul-server`, because, for historical reasons, some components use one name and some use the other.) These services all route to the `nginx` proxy.

### Verifying the installation
The first step in verifying that the remote proxy has been installed correctly is to verify that the expected Kubernetes entities have been created.  The `kubectl get` command can be used to do this.

For example, using the same assumptions about the environment as we did for the example deployment command above:
- `kubectl --context site-00 -n onap get deployments` should show the Kubernetes deployment for the `nginx` proxy server.
- `kubectl --context site-00 -n onap get pods` should show a pod running the `nginx` container.
- `kubectl --context site-00 -n onap get configmaps` should show the two ConfigMaps.
- `kubectl --context site-00 -n onap get services` should show the proxy service as well as all of the services from the `proxiedServices` list in `values.yaml`.

To check that the proxy is properly relaying requests to services running on the central site, use `kubectl exec` to launch a shell in the `nginx` container.  Using the example assumptions as above:
- Use `kubectl --context site-00 -n onap get pods` to get the name of the pod running the `nginx` proxy.
- Use `kubectl --context site-00 -n onap exec -it` _nginx_pod_name_ `/bin/bash` to enter a shell on the nginx container.
- The container doesn't have the `curl` and `nc` commands that we need to check connectivity. To install them, run the following commands _from the shell in the container_:
  - `apt-get update`
  - `apt-get install curl`
  - `apt-get install netcat`
- Check the HTTP and HTTPS services by attempting to access them using `curl`. Assuming the deployment used the default list of services from `values.yaml`, use the following commands:
  - `curl -v http://consul:8500/v1/agent/members`

  - `curl -v http://consul-server:8500/v1/agent/members`

  - `curl -v http://config-binding-service:10000/service_component/k8s-plugin`
  - `curl -v -H "X-DMAAP-DR-ON-BEHALF-OF: test" http://dmaap-dr-prov:8080/`
  - `curl -vk -H "X-DMAAP-DR-ON-BEHALF-OF: test" https://dmaap-dr-prov:8443/`
  - `curl -v http://dmaap-bc:8080/webapi/feeds`
  - `curl -vk https://dmaap-bc:8443/webapi/feeds`

    For all of the above commands, you should see an HTTP response from the server with a status of 200.  The exact contents of the response aren't important for the purposes of this test.  A response with a status of 502 or 504 indicates a problem with the proxy configuration (check the IP addresses of the cluster nodes) or with network connectivity from the remote site to the central site.

  - `curl -v http://message-router:3904/events/xyz`
  - `curl -kv https://message-router:3905/events/xyz`
  - `curl -v http://dmaap-dr-node:8080/`
  - `curl -kv https://dmaap-dr-node:8443/`

     These commands should result in an HTTP response from the server with a status code of 404.  The body of the response will have an error message.  This error is expected.  The fact that this type of error is returned indicates that there is connectivity to the central site DMaaP message router servers.  A response with a status of 502 or 504 indicates a problem with the proxy configuration or with network connectivity.

- Check the non-HTTP/HTTPS services by attempting to establish TCP connections to them using the `nc` command.  Assuming the deployment used the default list of services from `values.yaml`, there is only one such service to check, `log-ls`, the logstash service.  Use the following command:
  - `nc -v log-ls 5044`

    The command should give a response like this:

    `log-ls.onap.svc.cluster.local [` _private_ip_address_`] 5044 (?) open`

    where _private_ip_address_ is the local cluster IP address assigned to the log-ls service.

    The command will appear to hang, but it is just waiting for some TCP traffic to be passed across the connection.  To exit the command, type control-C.

    Error responses may indicate problems with the proxy configuration or with network connectivity from the remote site to the central site.




