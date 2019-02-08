# DCAE Consul Loader Container

The Dockerfile in this directory builds an image that can be used to spin up a container (typical a Kubernetes init container) that can load
service registrations and key-value pairs into a Consul instance.   This capability supports moving certain DCAE platform components from
deployment using a Cloudify blueprint and the ONAP Kubernetes plugin to a Helm-based deployment.  An init container can do the Consul
setup previously handled by the ONAP Kubernetes plugin and the ONAP DCAE bootstrap script.

The entrypoint for the container is the script `consul_store.sh`.  See the documentation for `consul_store.sh` to see how to provide arguments to the script
as well as how to use environment variables to set the Consul API protocol, host, and port.

Note that the container runs the script to completion.  It is not intended to be a long-running service.