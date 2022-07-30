# Policy Sync
This page serves as an implementation for the Policy sync container described in the [wiki](https://wiki.onap.org/display/DW/Policy+function+as+Sidecar)

Policy Sync utility is a python based utility that interfaces with the ONAP/ECOMP policy websocket and REST APIs. It is designed to keep a local listing of policies in sync with an environment's policy distribution point (PDP). It functions well as a Kubernetes sidecar container which can pull down the latest policies for consumption by an application container. 

The sync utility primarily utilizes the PDP's websocket notification API to receive policy update notifications. It also includes a periodic check of the  PDP for resilliency purposes in the event of websocket API issues. 

Policy Sync provides a way to realize runtime configuration for DCAE microservices through Policy Module. 

Currently, SON-Handler and SliceMS is utilizing policy sync.

## Build and Run
Easiest way to use is via docker by building the provided docker file

```bash
docker build . -t policy-puller
```

If you want to run it in a non containerized environment, an easy way is to use python virtual environments.
```bash
# Create a virtual environment in venv folder and activate it
python3 -m venv venv
source venv/bin/activate

# install the utility
pip install .

# Utility is now installed and usable in your virtual environment. Test it with:
policysync -h 
```

## Configuration

Configuration is currently done via either env variables or by flag. Flags take precedence env variables, env variables take precedence over default

### General configuration
General configuration that is used regardless of which PDP API you are using. 

| ENV Variable              | Flag               | Description                                  | Default                           |
| --------------------------| -------------------|----------------------------------------------|-----------------------------------|
| POLICY_SYNC_PDP_URL       | --pdp-url          | PDP URL to query                             | None (must be set in env or flag) |
| POLICY_SYNC_FILTER        | --filters          | yaml list of regex of policies to match      | []                                |
| POLICY_SYNC_ID            | --ids              | yaml list of ids of policies to match        | []                                |
| POLICY_SYNC_DURATION      | --duration         | duration in seconds for periodic checks      | 300                               |
| POLICY_SYNC_OUTFILE       | --outfile          | File to output policies to                   | ./policies.json                   |
| POLICY_SYNC_PDP_USER      | --pdp-user         | Set user if you need basic auth for PDP      | None                              |
| POLICY_SYNC_PDP_PASS      | --pdp-password     | Set pass if you need basic auth for PDP      | None                              |
| POLICY_SYNC_HTTP_METRICS  | --http-metrics     | Whether to expose prometheus metrics         | True                              |  
| POLICY_SYNC_HTTP_BIND     | --http-bind        | host:port for exporting prometheus metrics   | localhost:8000                    |
| POLICY_SYNC_LOGGING_CONFIG| --logging-config   | Path to a python formatted logging file      | None (logs will write to stderr)  |
| POLICY_SYNC_V0_ENABLE     | --use-v0         | Set to true to enable usage of legacy v0 API   | False                             |

### V1 Specific Configuration (Used as of the Dublin release)
Configurable variables used for the V1 API used in the ONAP Dublin Release.

Note: Policy filters are not currently supported in the current policy release but will be eventually. 

| ENV Variable                     | Flag                   | Description                            | Default                      |
| ---------------------------------|------------------------|----------------------------------------|------------------------------|
| POLICY_SYNC_V1_DECISION_ENDPOINT | --v1-decision-endpoint | Endpoint to query for PDP decisions    | policy/pdpx/v1/decision      |
| POLICY_SYNC_V1_DMAAP_URL         | --v1-dmaap-topic       | Dmaap url with topic for notifications | None                         |
| POLICY_SYNC_V1_DMAAP_USER        | --v1-dmaap-user        | User to use for DMaaP notifications    | None                         |
| POLICY_SYNC_V1_DMAAP_PASS        | --v1-dmaap-pass        | Password to use for DMaaP notifications| None                         |



### V0 Specific Configuration (Legacy Policy API)
Configurable variables used for the legacy V0 API Prior to the ONAP release. Only valid when --use-v0 is set to True


| ENV Variable                     | Flag                   | Description                            | Default                      |
| ---------------------------------|------------------------|----------------------------------------|------------------------------|
| POLICY_SYNC_V0_NOTIFIY_ENDPOINT  | --v0-notifiy-endpoint  | websock endpoint for pdp notifications |  pdp/notifications           |
| POLICY_SYNC_V0_DECISION_ENDPOINT | --v0-decision-endpoint | rest endpoint for pdp decisions        |  pdp/api                     |

## Usage

You can run in a pure docker setup:
```bash
# Run the container
docker run 
    --env POLICY_SYNC_PDP_USER=<username> \
    --env POLICY_SYNC_PDP_PASS=<password> \
    --env POLICY_SYNC_PDP_URL=<path_to_pdp> \
    --env POLICY_SYNC_V1_DMAAP_URL='https://<dmaap_host>:3905/events/<dmaap_topic>' \
    --env POLICY_SYNC_V1_DMAAP_PASS='<user>' \
    --env POLICY_SYNC_V1_DMAAP_USER='<pass>' \
    --env POLICY_SYNC_ID=['DCAE.Config_MS_AGING_UVERSE_PROD'] \
    -v $(pwd)/policy-volume:/etc/policy \
    nexus3.onap.org:10001/onap/org.onap.dcaegen2.deployments.policy-sync:1.0.1
```

Or on Kubernetes: 
```yaml
# policy-config-map
apiVersion: v1
kind: policy-config-map
metadata:
  name: special-config
  namespace: default
data:
  POLICY_SYNC_PDP_USER: myusername
  POLICY_SYNC_PDP_PASS: mypassword
  POLICY_SYNC_PDP_URL: <path_to_pdp>
  POLICY_SYNC_V1_DMAAP_URL: 'https://<dmaap_host>:3905/events/<dmaap_topic>' \
  POLICY_SYNC_V1_DMAAP_PASS: '<user>' \
  POLICY_SYNC_V1_DMAAP_USER: '<pass>' \
  POLICY_SYNC_FILTER: '["DCAE.Config_MS_AGING_UVERSE_PROD"]'
  
  
---

apiVersion: v1
kind: Pod
metadata:
  name: Sidecar sample app
spec:
  restartPolicy: Never
 
 
  # The shared volume that the two containers use to communicate...empty dir for simplicity
  volumes:
  - name: policy-shared
    emptyDir: {}
 
  containers:
 
  # Sample app that uses inotifyd (part of busybox/alpine). For demonstration purposes only...
  - name: main
    image: nexus3.onap.org:10001/onap/org.onap.dcaegen2.deployments.policy-sync:1.0.1
    volumeMounts:
    - name: policy-shared
      mountPath: /etc/policies.json
      subPath: policies.json
    # For details on what this does see: https://wiki.alpinelinux.org/wiki/Inotifyd
    # you can replace '-' arg below with a shell script to do more interesting
    cmd: [ "inotifyd", "-", "/etc/policies.json:c" ]
 
 
    # The sidecar app which keeps the policies in sync
  - name: policy-sync
    image: nexus3.onap.org:10001/onap/org.onap.dcaegen2.deployments.policy-sync:1.0.1
    envFrom:
      - configMapRef:
          name: special-config
    
    volumeMounts:
    - name: policy-shared
      mountPath: /etc/policies
```

## How to apply
Steps to utilize policy sync as a way to do runtime configuration:
1. Create policy Type: curl -k -v --user 'policyadmin:zb!XztG34' -X POST "https://{{Policy-API-IP}}:6969/policy/api/v1/policytypes" -H "Content-Type:application/json" -H "Accept: application/json" -d @policy_type.json 
2. Create xcaml policy: curl -v -k --silent --user 'policyadmin:zb!XztG34' -X POST "https://{{Policy-API-IP}}:6969/policy/api/v1/policytypes/{{PolicyType}}}/versions/{PolicyVersion}/policies" -H "Accept: application/json" -H "Content-Type: application/json" -d @policy.json
   * URL param "PolicyType" value is used to tell policy api which policy type should the current policy belongs to
   * URL param "PolicyType" value should refer to Policy Type Name you define in policy_type.json
   * URL param "PolicyVersion" value should refer to Version you define in policy.json
   * "Policy Id" defines in policy.json should be consistent with the "policyID" in /oom/kubernetes/dcaegen2-services/components/dcae-slice-analysis-ms/values.yaml
3. Deploy policy to xacml pdp engine: curl --silent -k --user 'policyadmin:zb!XztG34' -X POST "https://{{Policy-PAP-IP}}:6969/policy/pap/v1/pdps/policies" -H "Accept: application/json" -H "Content-Type: application/json" -d @deploy.json
4. Example policy_type.json, policy.json, deploy.json can be found in resources

