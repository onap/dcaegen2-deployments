## Dockerized bootstrap for Cloudify Manager and Consul cluster
1. Preparations

     a) The current DCAEGEN2 boot strapping process assumes that the networking in the OpenStack is based on the following model:

      a private network interconnecting the VMs; and an external network that provides "floating" IP addresses for the VMs.A router connects the two networks.  Each VM is assigned two IP addresses, one allocated from the private network when the VM is launched.
Then a floating IP is assigned to the VM from the external network. The UUID's of the private and external networks are needed for preparing the inputs.yaml file needed for running the bootstrap container.

   b) Add a public key to openStack, note its name (we will use KEYNAME as example for below).  Save the private key (we will use KEYPATH as its path example), make sure its permission is globally readable.

    c) Load the flowing base VM images to OpenStack:  a CentOS 7 base image and a Ubuntu 16.04 base image.

    d) Obtain the resource IDs/UUIDs for resources needed by the inputs.yaml file, as explained below, from OpenStack.

2. On dev machine, set up a directory to hold environment-specific configuration files. Call its path CONFIGDIR.

3. Put the private key mentioned above into CONFIGDIR as a file named `key`, and make it globally readable.
4. Create a file named `inputs.yaml` in CONFIGDIR

```
1  centos7image_id: '7c8d7524-de1f-490b-8418-db294bfa2d65'
2  ubuntu1604image_id: '4b09c18b-d69e-4ba8-a1bd-562cab91ff20'
3  flavor_id: '4'
4  security_group: '55a11193-6559-4f6c-b2d2-0119a9817062'
5  public_net: 'admin_floating_228_net'
6  private_net: 'onap-f-net'
7  openstack:
8    username: 'MY_LOGIN'
9    password: 'MY_PASSWORD'
10   tenant_name: 'TENANT_NAME'
11   auth_url: 'KEYSTONE_AUTH_URL'
12   region: 'RegionOne'
13 keypair: 'KEYNME'
14 key_filename: '/opt/dcae/key'
15 location_prefix: 'onapr1'
16 location_domain: 'onapdevlab.onap.org'
17 codesource_url: 'https://nexus.onap.org/service/local/repositories/raw/content'
18 codesource_version: 'org.onap.dcaegen2.deployments/releases/scripts'
```
Here is a line-by-line explanation of the parameters
  1. UUID of the OpenStack's CentOD 7 VM image
  2. UUID of the OpenStack's Ubuntu 16.04 VM image
  3. ID of the OpenStack's VM flavor to be used by DCAEGEN2 VMs
  4. UUID of the OpenStack's security group to be used for DCAEGEN2 VMs
  5. The name of the OpenStack network where public IP addresses are allocated from
  6. The name of the OpenStack network where private IP addresses are allocated from
  7. Group header for OpenStack Keystone parameters
  8. User name
  9. Password
  10. Name of the OpenStack tenant/project where DCAEGEN2 VMs are deployed
  11. penstack authentication API URL, for example 'https://horizon.playground.onap.org:5000/v2.0'
  12. Name of the OpenStack region where DCAEGEN2 VMs are deployed, for example 'RegionOne'
  13. Name of the public key uploaded to OpenStack in the Preparation step
  14. Path to the private key within the container (!! Do not change!!)
  15. Prefix (location code) of all DCAEGEN2 VMs
  16. Domain name of the OpenStack tenant 'onapr1.playground.onap.org'
  17. Location of the raw artifact repo hosting additional boot scripts called by DCAEGEN2 VMs' cloud-init, for example:
  'https://nexus.onap.org/service/local/repositories/raw/content'
  18. Path to the boot scripts within the raw artifact repo, for example: 'org.onap.dcaegen2.deployments/releases/scripts'


5. Create a file in CONFIGDIR called `invinputs.yaml`.  This contains environment-specific information for the inventory service.  (TODO: examples only, not the correct values for the ONAP integration environment.)

```
1 docker_host_override: "platform_dockerhost"
2 asdc_address: "sdc.onap.org:8443"
3 asdc_uri: "https://sdc.onap.org:8443"
4 asdc_user: "ci"
5 asdc_password: !!str 123456
6 asdc_environment_name: "ONAP-AMDOCS"
7 postgres_user_inventory: "postgres"
8 postgres_password_inventory: "onap123"
9 service_change_handler_image: "nexus3.onap.org:10001/onap/org.onap.dcaegen2.platform.servicechange-handler:latest"
10 inventory_image: "nexus3.onap.org:10001/onap/org.onap.dcaegen2.platform.inventory-api:latest
```
Here is a line-by-line description of the parameters:
  1. The service name for the platform docker host (should be the same in all environments)
  2. The hostname and port of the SDC service
  3. The URI of the SDC service
  4. The SDC username
  5. The SDC password
  6. The SDC environment name
  7. The postgres user name
  8. The postgres password
  9. The Docker image to be used for the service change handler (should be the same in all environments)
  10. The Docker image to be used for the inventory service (should be the same in all environments)

6. Create a file in CONFIGDIR called `phinputs.yaml`.  This contains environment-specific information for the policy handler.

```
application_config:
  policy_handler :
    # parallelize the getConfig queries to policy-engine on each policy-update notification
    thread_pool_size : 4

    # parallelize requests to policy-engine and keep them alive
    pool_connections : 20

    # retry to getConfig from policy-engine on policy-update notification
    policy_retry_count : 5
    policy_retry_sleep : 5

    # policy-engine config
    # These are the url of and the auth for the external system, namely the policy-engine (PDP).
    # We obtain that info manually from PDP folks at the moment.
    # In long run we should figure out a way of bringing that info into consul record
    #    related to policy-engine itself.
    policy_engine :
        url : "https://policy-engine.onap.org:8081"
        path_decision : "/decision/v1"
        path_pdp : "/pdp/"
        path_api : "/pdp/api/"
        headers :
            Accept : "application/json"
            "Content-Type" : "application/json"
            ClientAuth : "Basic bTAzOTQ5OnBvbGljeVIwY2sk"
            Authorization : "Basic dGVzdHBkcDphbHBoYTEyMw=="
            Environment : "TEST"
        target_entity : "policy_engine"
    # deploy_handler config
    #    changed from string "deployment_handler" in 2.3.1 to structure in 2.4.0
    deploy_handler :
        # name of deployment-handler service used by policy-handler for logging
        target_entity : "deployment_handler"
        # url of the deployment-handler service for policy-handler to direct the policy-updates to
        #   - expecting dns to resolve the hostname deployment-handler to ip address
        url : "http://deployment-handler:8188"
        # limit the size of a single data segment for policy-update messages
        #       from policy-handler to deployment-handler in megabytes
        max_msg_length_mb : 5
        query :
            # optionally specify the tenant name for the cloudify under deployment-handler
            #    if not specified the "default_tenant" is used by the deployment-handler
            cfy_tenant_name : "default_tenant"
```
TODO: provide explanations

7. Pull and run the docker container
```
docker login -u docker -p docker nexus3.onap.org:10001
docker pull nexus3.onap.org:10001/onap/org.onap.dcaegen2.deployments.bootstrap:1.1-latest0
docker run -d --name boot -v CONFIGDIR:/opt/app/installer/config -e "LOCATION=dg2" nexus3.onap.org:10003/onap/org.onap.dcaegen2.deployments.bootstrap:1.1-latest
```
The container stays up even after the installation is complete.  Using the docker exec command to get inside of the container, then run cfy commands to interact with the Cloudify Manager.

8. To tear down all of the DCAE installation:

```
docker exec -it boot ./teardown
```
