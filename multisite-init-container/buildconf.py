# ================================================================================
# Copyright (c) 2019 AT&T Intellectual Property. All rights reserved.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================
#
# Extract the API address and credentials provided
# to the container by Kubernetes and push it into a
# configmap that can be shared by other components
# and that can be augmented with addresses and credentials
# of remote Kubernetes clusters.

from kubernetes import client, config
import yaml
import string
import base64

# Default values for parameters
K8S_CENTRAL_LOCATION_ID = "central"                 # Used as cluster and context name in kubeconfig
K8S_USER = "user00"                                 # Used as user name in kubeconfig
CONFIG_MAP_NAME = "multisite-kubeconfig-configmap"    # Name of the existing ConfigMap that receives the kubeconfig
CONFIG_MAP_KEY = "kubeconfig"                       # Key in ConfigMap where kubeconfig is stored

def _get_config():
    ''' Get API access configuration as provided by k8s '''
    config.load_incluster_config()
    cfg = client.Configuration._default

    token = cfg.api_key['authorization'].split(' ')[1]
    server = cfg.host
    with open(cfg.ssl_ca_cert, 'r') as f:
        ca_cert = f.read().strip()

    ca_cert_string = base64.standard_b64encode(ca_cert.encode('utf-8'))

    return token, server, ca_cert_string

def _build_kubeconfig(location, kuser):
    ''' Build content of a kubeconfig file using the access info provided by k8s '''

    token, server, ca_cert = _get_config()
    cluster = {"name": location, "cluster": {"server": server, "certificate-authority-data": ca_cert}}
    user = {"name": kuser, "user": {"token": token}}
    context = {"name": location, "context": {"cluster": location, "user": kuser}}

    kubeconfig = {"apiVersion": "v1", "kind": "Config", "preferences": {}, "current-context": location}
    kubeconfig["clusters"] = [cluster]
    kubeconfig["users"] = [user]
    kubeconfig["contexts"] = [context]

    return kubeconfig

def update_kubeconfig_config_map(namespace, config_map_name, key, kubeconfig):
    body = client.V1ConfigMap(data={key: yaml.safe_dump(kubeconfig)})
    client.CoreV1Api().patch_namespaced_config_map(config_map_name, namespace, body)

def create_kubeconfig_file(location, user, config_file):
    ''' Write a kubeconfig file using the API access info provided by k8s '''
    with open(config_file, 'w') as f:
        yaml.safe_dump(_build_kubeconfig(location, user), f)

if __name__ == "__main__":
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option("-l", "--location", dest="location", help="Name of central location", default=K8S_CENTRAL_LOCATION_ID)
    parser.add_option("-u", "--user", dest="user", help="Username", default=K8S_USER)
    parser.add_option("-n", "--namespace", dest="namespace", help="Target namespace")
    parser.add_option("-c", "--configmap", dest="configmap", help= "ConfigMap name", default=CONFIG_MAP_NAME)
    parser.add_option("-k", "--key", dest="key", help="ConfigMap key (filename when ConfigMap is mounted)", default=CONFIG_MAP_KEY)
    (options, args) = parser.parse_args()
    kubeconfig = _build_kubeconfig(options.location, options.user)
    update_kubeconfig_config_map(options.namespace,options.configmap,options.key, kubeconfig)