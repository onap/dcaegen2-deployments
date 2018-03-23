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
