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