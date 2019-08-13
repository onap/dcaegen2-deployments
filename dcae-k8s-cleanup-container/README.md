# DCAE Cleanup Container
## Purpose
DCAE platform components (inventory, deployment handler, policy handler, etc.) are
deployed and undeployed using Helm.   DCAE service components--data collectors and
data analytics modules--are deployed using Cloudify, with the DCAE k8s plugin.
When DCAE is undeployed, Helm
has no way to undeploy the service components.  The artifacts in this directory
build a Docker image that can be run as a Kubernetes Job, using a Helm pre-delete hook.
The image runs a script that deletes the Kubernetes Services and Kubernetes Deployments
(and all of the ReplicaSets and Pods created as children of the Deployments) that were
created by the k8s plugin.

The script relies on the fact that Services and Deployments created by the k8s
plugin have a unique label ("cfydeployment").   The script finds Services and
Deployments with that label and deletes them.

## Running the container
The image is intended to be run as Kubernetes Job in a Helm pre-delete hook associated
with the OOM dcaegen2 charts.  A Helm template in the OOM dcaegen2 tree defines the Job.
The Job will start a container.  The container will execute the `dcae-cleanup.sh` script
and then exit.  The intent is that using a `helm undeploy` command will automatically
delete all of the DCAE service components, so that no additional cleanup is needed.

The container can be run manually using the `kubectl run` command.  For example:
```
kubectl -n onap run --restart='OnFailure' --image dcae-cleanup:0.0.0 cleanup
```
The `--restart='OnFailure'` parameter causes kubectl to create a Job.