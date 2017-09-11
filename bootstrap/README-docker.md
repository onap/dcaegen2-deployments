## Dockerized bootstrap for Cloudify Manager and Consul cluster

1. Preparations
a) Add a public key to openStack, note its name (we will use KEYNAME as example for below).  Save the private key (we will use KAYPATH as its path example), make sure it's permission is globally readable.
b) Load the folowing base VM images to OpenStack:  a CentOS 7 base image and a Ubuntu 16.04 base image. 
c) Obatin the resource IDs/UUIDs for resources needed by the inputs.yaml file, as explained belowi, from OpenStack.
d) DCAEGEN2 boot straping assumes that VMs are assigned private IP addresses from a network.  Each VM can also be assigned a floating public IP address from another network.


2. On dev machine, edit an inputs.yaml file at INPUTSYAMLPATH
```
1	centos7image_id: '7c8d7524-de1f-490b-8418-db294bfa2d65'
2	ubuntu1604image_id: '4b09c18b-d69e-4ba8-a1bd-562cab91ff20'
3	flavor_id: '4'
4	security_group: '55a11193-6559-4f6c-b2d2-0119a9817062'
5	public_net: 'admin_floating_228_net'
6	private_net: 'onap-f-net'
7	openstack:
8	  username: 'MY_LOGIN'
9	  password: 'MY_PASSWORD'
10	  tenant_name: 'TENANT_NAME'
11	  auth_url: 'KEYSTONE_AUTH_URL'
12	  region: 'RegionOne'
13	keypair: 'KEYNME'
14	key_filename: '/opt/dcae/key'
15	location_prefix: 'onapr1'
16	location_domain: 'onap-f.onap.homer.att.com'
17	codesource_url: 'https://nexus01.research.att.com:8443/repository'
18	codesource_version: 'solutioning01-mte2'
```
Here is a line-by-line explanation of the arameters
1       UUID of the OpenStack's CentOD 7 VM image
2       UUID of the OpenStack's Ubuntu 16.04 VM image
3       ID of the OpenStack's VM flavor to be used by DCAEGEN2 VMs
4       UUID of the OpenStack's security group to be used for DCAEGEN2 VMs
5	The name of the OpenStack network where public IP addresses are allocated from
6	The name of the OpenStack network where private IP addresses are allocated from
7	Group header for OpenStack Keystone parameters
8       User name
9       Password
10      Name of the OpenStack tenant/project where DCAEGEN2 VMs are deployed
11      Openstack authentication API URL, for example 'https://horizon.playground.onap.org:5000/v2.0'
12      Name of the OpenStack region where DCAEGEN2 VMs are deployed, for example 'RegionOne'
13      Name of the public key uploaded to OpenStack in the Prepration step
14      Path to the private key within the conatiner (!! Do not change!!)
15      Prefix (location code) of all DCAEGEN2 VMs
16      Domain name of the OpenStack tenant 'onapr1.playground.onap.org'
17      Location of the raw artifact repo hosting additional boot scripts called by DCAEGEN2 VMs' cloud-init, for example: 
        'https://nexus.onap.org/service/local/repositories/raw/content'
18      Path to the boot scripts within the raw artifact repo, for example: 'org.onap.dcaegen2.deployments.scripts/releases/' 


3. Pull and run the docker conatiner
```
docker pull nexus3.onap.org:10003/onap/org.onap.dcaegen2.deployments.bootstrap:1.0


docker run -d -v /home/ubuntu/JFLucasBootStrap/utils/platform_base_installation/key:/opt/app/installer/config/key -v /home/ubuntu/JFLucasBootStrap/utils/platform_base_installation/inputs.yaml:/opt/app/installer/config/inputs.yaml -e "LOCATION=dg2" bootstrap

docker run -d -v KEYPATH:/opt/app/installer/config/key -v INPUTSYAMLPATH:/opt/app/installer/config/inputs.yaml -e "LOCATION=dg2" nexus3.onap.org:10003/onap/org.onap.dcaegen2.deployments.bootstrap:1.0

```


R
`expand.sh` expands the blueprints and the installer script so they
point to the repo where the necessary artifacts (plugins, type files)
are store.

`docker build -t bootstrap .`  builds the image

`docker run -d -v /path/to/worldreadable_private_key:/opt/app/installer/config/key -v /path/to/inputs_file:/opt/app/installer/config/inputs.yaml -e "LOCATION=location_id_here" --name bsexec bootstrap`  runs the container and (if you're lucky) does the deployment.

(
1. the private key is THE private key for the public key added to OpenStack
2. the path to inputs and key file are FULL path starting from /
3. --name is optional.  if so the container name will be random
)


`example-inputs.yaml` is, as the name suggests, an example inputs file.  The values in it work in the ONAP-Future environment, except for the
user name and password.

To watch the action use
`docker logs -f bsexec`

The container stays up even after the installation is complete.
To enter the running container:
`docker exec -it bsexec /bin/bash`
Once in the container, to uninstall CM and the host VM and its supporting entities
`source dcaeinstall/bin/active`
`cfy local uninstall`

(But remember--before uninstalling CM, be sure to go to CM first and uninstall the Consul cluster.)


####TODOS:
- Integrate with the maven-based template expansion.
- Integrate with maven-based Docker build and push to LF Docker repo
- Add full list of plugins to be installed onto CM
- Separate the Docker stuff from the non-Docker installation.  (The blueprints are common to both methods.)
- Get rid of any AT&T-isms
- (Maybe) Move the installation of the Cloudify CLI and the sshkeyshare and dnsdesig plugins into the Dockerfile,
so the image has everything set up and can just enter the vevn and start the Centos VM installation.
- Figure out what (if anything) needs to change if the container is deployed by Kubernetes rather than vanilla Docker
- Make sure the script never exits, even in the face of errors.  We need the container to stay up so we can do uninstalls.
- Figure out how to add in the deployments for the rest of the DCAE platform components.  (If this container deploys all of DCAE,
should it move out of the CCSDK project and into DCAE?)
- Figure out the right way to get the Cloudify OpenStack plugins and the Cloudify Fabric plugins onto CM.  Right now there are
handbuilt wagons in the Nexus repo.  (In theory, CM should be able to install these plugins whenever a blueprint calls for them.  However,
they require gcc, and we're not installing gcc on our CM host.)
- Maybe look at using a different base image--the Ubuntu 16.04 image needs numerous extra packages installed.
- The blueprint for Consul shows up in Cloudify Manager with the name 'blueprints'.  I'll leave it as an exercise for the reader to figure why
and to figure out how to change it.  (See ~ line 248 of installer-docker.sh-template.)
