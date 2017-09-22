## Dockerized bootstrap for Cloudify Manager and Consul cluster
1. Preparations
a) The current DCAEGEN2 boot strapping process assumes that the networking in the OpenStack is based on the following model:
a private network interconnecting the VMs; and an external network that provides "floating" IP addresses for the VMs.A router connects the two networks.  Each VM is assigned two IP addresses, one allocated from the private network when the VM is launched.
Then a floating IP is assigned to the VM from the external network. The UUID's of the private and external networks are needed for preparing the inputs.yaml file needed for running the bootstrap container.
b) Add a public key to openStack, note its name (we will use KEYNAME as example for below).  Save the private key (we will use KAYPATH as its path example), make sure it's permission is globally readable.
c) Load the flowing base VM images to OpenStack:  a CentOS 7 base image and a Ubuntu 16.04 base image.
d) Obtain the resource IDs/UUIDs for resources needed by the inputs.yaml file, as explained below, from OpenStack.
2. On dev machine, edit an inputs.yaml file at INPUTSYAMLPATH
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
3. Pull and run the docker container
```
docker pull nexus3.onap.org:10003/onap/org.onap.dcaegen2.deployments.bootstrap:1.0
docker run -v KEYPATH:/opt/app/installer/config/key -v INPUTSYAMLPATH:/opt/app/installer/config/inputs.yaml -e "LOCATION=dg2" nexus3.onap.org:10003/onap/org.onap.dcaegen2.deployments.bootstrap:1.0
```
The container stays up even after the installation is complete.  Using the docker exec command to get inside of the container, then run cfy commands to interact with the Cloudify Manager.