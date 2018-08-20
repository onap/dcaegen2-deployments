# PNDA Mirror
## Purpose
The artifacts in this directory build a Docker image based public PNDA mirror
creation scripts. The container have all the needed offline resources to
deploy a PNDA platform.

## Running the Container
The container is intended to be launched via a Helm chart as part
of the ONAP deployment process, guided by OOM. It can be run directly
into a native Docker environment, using:
```
docker run --name pnda-mirror -d --restart unless-stopped \
   -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
   -p <some_external_port>:8080 \
   --tmpfs /run \
   --tmpfs /run/lock \
   --security-opt seccomp:unconfined
   --cap-add SYS_ADMIN \
   <image_name>
```

We also expect that in a Kubernetes environment the external port mapping would not be
needed.
