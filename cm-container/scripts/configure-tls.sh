#!/bin/bash
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2019 AT&T Intellectual Property. All rights reserved.
# Copyright (c) 2020-2021 J. F. Lucas.  All rights reserved.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================
#

# Set tls to "enabled"
sed -i -e "s#^    ssl_enabled: false#    ssl_enabled: true#" /etc/cloudify/config.yaml
# Set up paths for our certificates
sed -i -e "s|external_cert_path: .*$|external_cert_path: '/opt/onap/certs/cert.pem'|" /etc/cloudify/config.yaml
sed -i -e "s|external_key_path: .*$|external_key_path: '/opt/onap/certs/key.pem'|" /etc/cloudify/config.yaml
sed -i -e "s|external_ca_cert_path: .*$|external_ca_cert_path: '/opt/onap/certs/cacert.pem'|" /etc/cloudify/config.yaml
# Set the host name for the local profile
# Otherwise, the CM startup process will use 'localhost' and will fail
# because the TLS certificate does not have 'localhost' as a CN or SAN
sed -i -e 's/  cli_local_profile_host_name: .*$/  cli_local_profile_host_name: dcae-cloudify-manager/' /etc/cloudify/config.yaml
