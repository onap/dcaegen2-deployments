# Cloudify Manager Container Builder
## Purpose
The artifacts in this directory build a Docker image based on the
public image from Cloudify (`cloudifyplatform/community`).  The
image has the Cloudify Manager software from the base image
and adds our types files.  It edits `/etc/cloudify/config.yaml`
to configure the import resolver to use our local type files instead
of fetching them over the Internet.   It adds
Cloudify 3.4 type files that are still used in some plugins
and blueprints.  Finally, it sets up the `/opt/onap` mount point
for our config files.

## Running the Container
The container is intended to be launched via a Helm chart as part
of the ONAP deployment process, guided by OOM. It can be run directly
into a native Docker environment, using:
```
docker run --name cfy-mgr -d --restart unless-stopped \
   -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
   -p <some_external_port>:80 \
   --tmpfs /run \
   --tmpfs /run/lock \
   --security-opt seccomp:unconfined
   --cap-add SYS_ADMIN \
   -v <path_to_kubeconfig_file>:/etc/cloudify/.kube/config
   -v <path_to_config_file>:/opt/onap/config.txt
   <image_name>
```
In a Kubernetes environment, we expect that the <path_to_kubeconfile_file> and the
<path_to_config_file> mounts would be Kubernetes ConfigMaps.

We also expect that in a Kubernetes environment the external port mapping would not be
needed.

## Persistent Storage
In an ONAP deployment driven by OOM, Cloudify Manager will store data related to its state
in a Kubernetes PersistentVolume.  If the Cloudify Manager pod is destroyed and recreated,
the new instance will have all of the state information from the previous run.

To set up persistent, we replace the command run by the container (`CMD` in the Dockerfile) with
our own script `start-persistent.sh`.  This script checks to see if a persistent volume has been
mounted in a well-known place (`/cfy-persist` in the container's file system).  If so, the script
then checks to see if the persistent volume has been populated with data.  There are two possibilities:
1. The persistent volume hasn't been populated, indicating that this is the first time Cloudify Manager is
being run in the current environment.  In this case, the script copies state data from several directories in
the container file system into directories in the persistent volume.  This is data (such as database schemas for
Cloudify Manager's internal postgres instance) that was generated when the original Cloudify Manager image was
created by Cloudify.
2. The persistent volume has been populated, indicating that this is not the first time Cloudify Manager is being
run in the current environment.   The data in the persistent volume reflects the state that Cloudify Manager was in
when it exited at some point in the past.   There's no need to copy data in this case.
In either case, the script will create symbolic links from the original data directories to the corresponding directories
in the persistent store.

If there is no persistent volume mounted, the script does nothing to set up persistent data, and the container will have
no persistent storage.

The last command in the script is the command from the original Cloudify version of the Cloudify Manager image. It runs `/sbin/init`,
which then brings up the many other processes needed for a working instance of Cloudify Manager.

## The `setup-secret.sh` script
When Kubernetes starts a container, it mounts a directory containing the credentials that the container needs to access the Kubernetes API on the local Kubernetes cluster.  The mountpoint is `/var/run/secrets/kubernetes.io/serviceaccount`.   Something about the way that Cloudify Manager is started (possibly because `/sbin/init` is run) causes this mountpoint to be hidden.   `setup-secret.sh` will recreated the directory if it's not present and symbolically link it to a copy of the credentials mounted at `/secret` in the container file system.  This gives Cloudify Manager the credentials that the Kubernetes plugin needs to deploy Kubernetes-based DCAE components.

`setup-secret.sh` needs to run after '/sbin/init'.  The Dockerfile installs it in the `rc.local` script that runs at startup.

## Cleaning up Kubernetes components deployed by Cloudify Manager
Using the `helm undeploy` (or `helm delete`) command will destroy the Kubernetes components deployed via helm.  In an ONAP deployment
driven by OOM, this includes destroying Cloudify Manager.  helm will *not* delete Kubernetes components deployed by Cloudify Manager.
This includes components ("microservices") deployed as part of the ONAP installation process by the DCAE bootstrap container as well as
components deployed after the initial installation using CLAMP.   Removing *all* of DCAE, including any components deployed by Cloudify
Manager, requires running a command before running the `helm undeploy` or `helm delete` command.

```kubectl -n _namespace_ exec _cloudify_manager_pod_ /scripts/dcae-cleanup.sh```
where _namespace_ is the namespace in which ONAP was deployed and _cloudify_manager_pod_ is the ID of the pod running Cloudify Manager.

For example:
```
$ kubectl -n onap exec dev-dcaegen2-dcae-cloudify-manager-bf885f5bd-hm97x /scripts/dcae-cleanup.sh
+ set +e
++ grep admin_password: /etc/cloudify/config.yaml
++ cut -d : -f2
++ tr -d ' '
+ CMPASS=admin
+ TYPENAMES='[\"dcae.nodes.ContainerizedServiceComponent\",\"dcae.nodes.ContainerizedServiceComponentUsingDmaap\",\"dcae.nodes.ContainerizedPlatformComponent\",\"dcae.nodes.ContainerizedApplication\"]'
+ xargs -I % sh -c 'cfy executions start -d %  -p '\''{'\''\"type_names\":[\"dcae.nodes.ContainerizedServiceComponent\",\"dcae.nodes.ContainerizedServiceComponentUsingDmaap\",\"dcae.nodes.ContainerizedPlatformComponent\",\"dcae.nodes.ContainerizedApplication\"],\"operation\":\"cloudify.interfaces.lifecycle.stop\"'\''}'\'' execute_operation'
+ /bin/jq '.items[].id'
+ curl -Ss --user admin:admin -H 'Tenant: default_tenant' 'localhost/api/v3.1/deployments?_include=id'
Executing workflow execute_operation on deployment pgaas_initdb [timeout=900 seconds]
2019-03-06 23:06:06.838  CFY <pgaas_initdb> Starting 'execute_operation' workflow execution
2019-03-06 23:06:07.518  CFY <pgaas_initdb> 'execute_operation' workflow execution succeeded
Finished executing workflow execute_operation on deployment pgaas_initdb
* Run 'cfy events list -e c88d5a0a-9699-4077-961b-749384b1e455' to retrieve the execution's events/logs
Executing workflow execute_operation on deployment hv-ves [timeout=900 seconds]
2019-03-06 23:06:14.928  CFY <hv-ves> Starting 'execute_operation' workflow execution
2019-03-06 23:06:15.535  CFY <hv-ves> [hv-ves_dlkit2] Starting operation cloudify.interfaces.lifecycle.stop
2019-03-06 23:06:15.535  CFY <hv-ves> [hv-ves_dlkit2.stop] Sending task 'k8splugin.stop_and_remove_container'
2019-03-06 23:06:16.554  CFY <hv-ves> [hv-ves_dlkit2.stop] Task started 'k8splugin.stop_and_remove_container'
2019-03-06 23:06:20.163  CFY <hv-ves> [hv-ves_dlkit2.stop] Task succeeded 'k8splugin.stop_and_remove_container'
2019-03-06 23:06:20.561  CFY <hv-ves> [hv-ves_dlkit2] Finished operation cloudify.interfaces.lifecycle.stop
2019-03-06 23:06:21.570  CFY <hv-ves> 'execute_operation' workflow execution succeeded
Finished executing workflow execute_operation on deployment hv-ves
* Run 'cfy events list -e b4ea6608-befd-421d-9851-94527deab372' to retrieve the execution's events/logs
Executing workflow execute_operation on deployment datafile-collector [timeout=900 seconds]
2019-03-06 23:06:27.471  CFY <datafile-collector> Starting 'execute_operation' workflow execution
2019-03-06 23:06:28.593  CFY <datafile-collector> [datafile-collector_j2b0r4] Starting operation cloudify.interfaces.lifecycle.stop
2019-03-06 23:06:28.593  CFY <datafile-collector> [datafile-collector_j2b0r4.stop] Sending task 'k8splugin.stop_and_remove_container'
2019-03-06 23:06:28.593  CFY <datafile-collector> [datafile-collector_j2b0r4.stop] Task started 'k8splugin.stop_and_remove_container'
2019-03-06 23:06:32.078  CFY <datafile-collector> [datafile-collector_j2b0r4.stop] Task succeeded 'k8splugin.stop_and_remove_container'
2019-03-06 23:06:32.609  CFY <datafile-collector> [datafile-collector_j2b0r4] Finished operation cloudify.interfaces.lifecycle.stop
2019-03-06 23:06:32.609  CFY <datafile-collector> 'execute_operation' workflow execution succeeded
Finished executing workflow execute_operation on deployment datafile-collector
* Run 'cfy events list -e 24749c7e-591f-4cac-b127-420b0932ef09' to retrieve the execution's events/logs
Executing workflow execute_operation on deployment ves [timeout=900 seconds]
```
The exact content of the output will depend on what components have been deployed.  Note that in the example output
above, the `pgaas_initdb` node was visited, but no 'stop' operation was sent because `pgaas_initdb` is not a Kubernetes node.

