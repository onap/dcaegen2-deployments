#!/bin/bash
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2019 AT&T Intellectual Property. All rights reserved.
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
# Set up configuration files so that CM uses TLS on its external API

# Change the nginx configuration -- this is what actually makes it work
SSLCONFPATTERN="^include \"/etc/nginx/conf.d/http-external-rest-server.cloudify\""
SSLCONFREPLACE="include \"/etc/nginx/conf.d/https-external-rest-server.cloudify\""
sed -i -e "s#${SSLCONFPATTERN}#${SSLCONFREPLACE}#" /etc/nginx/conf.d/cloudify.conf

# Set certificate and key locations
sed -i -e "s#  ssl_certificate .*;#  ssl_certificate     /opt/onap/certs/cert.pem;#" /etc/nginx/conf.d/https-external-rest-server.cloudify
sed -i -e "s#  ssl_certificate_key .*;#  ssl_certificate_key     /opt/onap/certs/key.pem;#" /etc/nginx/conf.d/https-external-rest-server.cloudify

# Change the cloudify config file, just to be safe
# Someone might run cfy_manager configure on the CM container for some reason
# and we don't want them to overwrite the TLS configuration
# (Running cfy_manager configure is a bad idea, though, because it often fails.)
sed -i -e "s#^    ssl_enabled: false#    ssl_enabled: true#" /etc/cloudify/config.yaml

# The Cloudify command line tool ('cfy') needs to be configured for TLS as well
# (The readiness check script uses 'cfy status')
sed -i -e "s#^rest_port: 80#rest_port: 443#" /root/.cloudify/profiles/localhost/context
sed -i -e "s/^rest_protocol: http$/rest_protocol: https/" /root/.cloudify/profiles/localhost/context
sed -i -e "s#^rest_certificate: !!python/unicode '/etc/cloudify/ssl/cloudify_external_cert.pem'#rest_certificate: !!python/unicode '/opt/onap/certs/cacert.pem'#" /root/.cloudify/profiles/localhost/context
sed -i -e "s#^manager_ip: !!python/unicode 'localhost'#manager_ip: !!python/unicode 'dcae-cloudify-manager'#" /root/.cloudify/profiles/localhost/context
