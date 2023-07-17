# DCAE Healthcheck Service

The Healthcheck service provides a simple HTTP API to check the status of DCAE components running in the Kubernetes environment.  When it receives any incoming HTTP request, the service makes queries to the Kubernetes API to determine the current status of the DCAE components, as seen by Kubernetes.  Most components have defined a "readiness probe" (an HTTP healthcheck endpoint or a healthcheck script) that Kubernetes uses to determine readiness.  The Healthcheck service itself does not directly connect to the DCAE components to check their status.

A single instance of the DCAE Healthcheck service is deployed in ONAP.

The Healthcheck service has two sources for identifying components that should be running:
1. A list of components that are expected to be deployed by Helm as part of the ONAP installation, specified in a JSON array stored in a file at `/opt/app/expected-components.json`.

    The DCAE ONAP deployment (using the OOM dcaegen2-services Helm charts) is configurable.  By setting flags in the `values.yaml` file or in an override file, a user can select which components are deployed.  The`/opt/app/expected-components.json` file is generated at deployment time based on which components have been selected for deployment.  The file is stored in a Kubernetes ConfigMap that is mounted on the healthcheck container at `/opt/app/expected-components.json`.   See the Helm charts for dcaegen2-services in the OOM repository for details on how the ConfigMap is created.

2. Components whose Kubernetes deployments have been marked with the label whose name is given by the environment variable `DEPLOY_LABEL`. The dcaegen2-services-common deployment template inserts this label into every deployment that uses the template. On every incoming HTTP request, the Healthcheck
service queries the Kubernetes API to get a list of all the deployments that have this label.   This allows the Healthcheck service to detect components that
have been deployed after the initial DCAE ONAP deployment.

_Note that since the London release, having two methods for determining what components should be running is (arguably) redundant.  The label method is (arguably)sufficient.  The two methods are historical.  At one time, as many as three different instances of the Healthcheck service ran in ONAP, and two of them did not have labeling.  The counterargument for keeping the "expected components" test along with the labeling test is that if there is some error in the Helm charts that prevents a Kubernetes deployment being created for one of the "expected components", that expected component will not come up, but the healthcheck will not test for it._

The Healthcheck service returns an HTTP status code of 200 if Kubernetes reports that all of the components that should be running are in a ready state.  It returns a status code of 500 if some of the components are not ready.  It returns a status code of 503 if some kind of error prevented it from completing a query.

For the 200 and 500 status codes, the Healthcheck service returns a body consisting of a JSON object.  The object has the following fields:
- `type` : the type of response, currently always set to `summary`.
- `count`: the total number of deployments that have been checked.
- `ready`: the number of deployments in the ready state
- `items`: a JSON list(array) of objects, one for each deployment.  Each object has the form:
`{"name": "k8s_deployment_name", "ready": number_of_ready_instances, "unavailable": number_number_of_unavailable_instances}`

Here's an example of the body. It's showing the four components that are deployed automatically by default when dcaegen2-services is installed (dev-dcae-hv-ves-collector, dev-dcae-prh, dev-dcae-tcagen2, and dev-dcae-ves-collector) along with three components that were deployed (in separate Helm releases) after dcaegen2-services was installed (nginx-dcae-nginx, nginxinst2-dcae-nginx, and nginxinst3-dcae-nginx).  Note that nginx-dcae-nginx is not ready.
```
{
  "type": "summary",
  "count": 7,
  "ready": 6,
  "items": [
    {
      "name": "dev-dcae-hv-ves-collector",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dev-dcae-prh",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dev-dcae-tcagen2",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "dev-dcae-ves-collector",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "nginx-dcae-nginx",
      "ready": 0,
      "unavailable": 1
    },
    {
      "name": "nginxinst2-dcae-nginx",
      "ready": 1,
      "unavailable": 0
    },
    {
      "name": "nginxinst3-dcae-nginx",
      "ready": 1,
      "unavailable": 0
    }
  ]
}
```
