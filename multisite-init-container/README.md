# Multisite Initialization Container
This container sets up the initial entry in a kubeconfig file that
Cloudify Manager (and potentially other components) can use to access
multiple Kubernetes clusters.   The initial entry is for the central
site.

The container runs a short Python script to completion.  It's meant to be
run as an init container or as a standalone Kubernetes Job. (In the R4 ["Dublin"] release, it's
run as an init container for the Cloudify Manager pod.)   The script works by
using the Kubernetes API to get three pieces of information about the cluster where the script is running:
  1. the address of the Kubernetes API server
  2. the CA certificate for the server
  3. an authorization token that can be presented with each API request.

The script combines this information with other values provided from command line arguments and/or defaults
to create a kubeconfig-style structure that it uses to update an existing Kubernetes ConfigMap.  (It uses an
existing ConfigMap, rather than creating a new one, in order to work well with the OOM Helm deployment
strategy.  The OOM Helm charts create an empty ConfigMap, so that Helm knows about the ConfigMap and can delete
it cleanly when uninstalling.  If the script created a new ConfigMap,
Helm would not know about it and would not delete it during an uninstall
operation.)

The table below shows the command line arguments that can be passed to the script via the "args" array in the
Kubernetes spec for the container.
| Argument | Description | Required? | Default
|----------|-------|-----------|--------
|--namespace, -n | Namespace where CM will run | Yes | None
|--location, -l  | Name of the central location | No | "central"
|--user, -u | User name for authorization | No | "user00"
|--configmap, -c | Name of the ConfigMap where the kubeconfig is stored | No | "multisite-kubeconfig-configmap"
|--key, -k | Key under which the kubeconfig is stored (when mounted on a container, this will be file name)| No | "kubeconfig"


