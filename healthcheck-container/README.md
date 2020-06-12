# DCAE and DCAE MOD Healthcheck Service

The Healthcheck service provides a simple HTTP API to check the status of DCAE or DCAE MOD components running in the Kubernetes environment.  When it receives any incoming HTTP request, the service makes queries to the Kubernetes API to determine the current status of the DCAE or DCAE MOD components, as seen by Kubernetes.  Most components have defined a "readiness probe" (an HTTP healthcheck endpoint or a healthcheck script) that Kubernetes uses to determine readiness.

Two instances of the Healthcheck service are deployed in ONAP: one for DCAE and one for DCAE MOD.

The Healthcheck service has two sources for identifying components that should be running:
1. A list of components that are expected to be deployed by Helm as part of the ONAP installation, specified in a JSON array stored in a file at `/opt/app/expected-components.json`.

    DCAE and DCAE MOD have configurable deployments.  By setting flags in the `values.yaml` file or in an override file, a user can select which components are deployed.  The`/opt/app/expected-components.json` file is generated at deployment time based on which components have been selected for deployment.  The file is stored in a Kubernetes ConfigMap that is mounted on the healthcheck container at `/opt/app/expected-components.json`.   See the Helm charts for DCAE and DCAEMOD in the OOM repository for details on how the ConfigMap is created.

2. Components whose Kubernetes deployments have been marked with the labeled specified by the environment variable `DEPLOY_LABEL`.  These are identified by a query to the Kubernetes API requesting a list of all the deployments with the label.  The query is made each time an incoming HTTP request is made, so that as new deployments are created, they will be detected and included in the health check.

    For the DCAE instance of the Healthcheck service, the `DEPLOY_LABEL` variable is set to `cfydeployment`.  This is the label that the DCAE k8s Cloudify plugin uses to mark every deployment that it creates.  The DCAE Healthcheck instance therefore includes all components deployed by the DCAE k8s plugin in its health check.  For the DCAE MOD instance of the Healthcheck service, the `DEPLOY_LABEL` is not set, so the DCAE MOD health check does not make any checks based on a label.

The Healthcheck service returns an HTTP status code of 200 if Kubernetes reports that all of the components that should be running are in a ready state.  It returns a status code of 500 if some of the components are not ready.  It returns a status code of 503 if some kind of error prevented it from completing a query.

For the 200 and 500 status codes, the Healthcheck service returns a body consisting of a JSON object.  The object has the following fields:
- `type` : the type of response, currently always set to `summary`.
- `count`: the total number of deployments that have been checked.
- `ready`: the number of deployments in the ready state
- `items`: a JSON list(array) of objects, one for each deployment.  Each object has the form:
`{"name": "k8s_deployment_name", "ready": number_of_ready_instances, "unavailable": number_number_of_unavailable_instances}`

Here's an example of the body, with one component in an unavailable state:
```
{
  "type": "summary",
  "count": 14,
  "ready": 13,
  "items": [
    {
      "name": "dev-dcaegen2-dcae-cloudify-manager",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-config-binding-service",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-deployment-handler",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-inventory",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-service-change-handler",
      "ready": 0,
      "unavailable": 1
    },
    {
      "name": "dep-policy-handler",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-dcae-ves-collector",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-dcae-tca-analytics",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-dcae-prh",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-dcae-hv-ves-collector",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-dcae-datafile-collector",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-dcae-snmptrap-collector",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-holmes-engine-mgmt",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dep-holmes-rule-mgmt",
      "ready": 1,
      "unavailable": 0
    }
  ]
}
```