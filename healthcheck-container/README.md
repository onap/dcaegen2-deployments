# DCAE Healthcheck Service

The DCAE Healthcheck service provides a simple HTTP API to check the status of DCAE components running in the Kubernetes environment.  When it receives any incoming HTTP request, the service makes queries to the Kubernetes API to determine the current status of the DCAE components, as seen by Kubernetes.  Most components have defined a "readiness probe" (an HTTP healthcheck endpoint or a healthcheck script) that Kubernetes uses to
determine readiness.

The Healthcheck service has three sources for identifying components that should be running:
1. A hardcoded list of components that are expected to be deployed by Helm as part of the ONAP installation.
2. A hardcoded list of components thar are expected to be deployed with blueprints using Cloudify Manager during DCAE bootstrapping, which is part of ONAP installation.
3. Components labeled in Kubernetes as having been deployed by Cloudify Manager.  These are identified by a query to the Kubernetes API.  The query is made each time an incoming HTTP request is made.

Note that by "component", we mean a Kubernetes Deployment object associated with the component.

Sources 2 and 3 are likely to overlap (the components in source 2 are labeled in Kubernetes as having been deployed by Cloudify Manager, so they will show up as part of source 3 if the bootstrap process progressed to the point of attempting deployments).  The code de-duplicates these sources.

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