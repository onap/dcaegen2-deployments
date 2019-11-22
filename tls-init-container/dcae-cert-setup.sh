#!/bin/bash
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
set -e
set -x

# Set sensible DCAE defaults for environment variables needed by AAF.
# These can be overriden by setting the environment variables on the container
export APP_FQI=${APP_FQI:-"dcae@dcae.onap.org"}
export aaf_locate_url=${aaf_locate_url:-"https://aaf-locate.onap:8095"}
export aaf_locator_container=${aaf_locator_container:-"oom"}
export aaf_locator_container_ns=${aaf_locator_container_ns:-"onap"}
export aaf_locator_app_ns=${aaf_locator_app_ns:-"org.osaaf.aaf"}
export DEPLOY_FQI=${DEPLOY_FQI:-"deployer@people.osaaf.org"}
export DEPLOY_PASSWORD=${DEPLOY_PASSWORD:-"demo123456!"}
export cadi_longitude=${cadi_longitude:-"-72.0"}
export cadi_latitude=${cadi_latitude:-"38.0"}

# For now, we can default aaf_locator_fqdn
# This points to the single DCAE cert with many SANs,
# as used in previous releases
# When we have individual certs per component, we will override this
# by setting the environment variable explicitly in a Helm chart
# or via the k8s plugin
export aaf_locator_fqdn=${aaf_locator_fqdn:-"dcae"}

# Our own environment variable to signal that the tls-init-container
# is being run for a component that is a TLS server
export TLS_SERVER=${TLS_SERVER:-"true"}

# Directory where AAF agent puts artifacts
ARTIFACTS=/opt/app/osaaf/local
# Directory where DCAE apps expect artifacts
TARGET=/opt/app/osaaf

# AAF namespace for the certs--used in naming artifacts
AAFNS=org.onap.dcae

# Dummy certificate FQDN for client-only components
# Must be set up in AAF, but won't actually be used
DUMMY_FQDN=dcae

# Clean out any existing artifacts
rm -rf ${ARTIFACTS}
rm -f ${TARGET}/*

# Set the dummy FQDN for a client-only component
if [ "${TLS_SERVER}" == "false" ]
then
    export aaf_locator_fqdn=${DUMMY_FQDN}
fi

# Get the certificate artifacts from AAF
/opt/app/aaf_config/bin/agent.sh

# Extract the p12 and JKS passwords
/opt/app/aaf_config/bin/agent.sh aafcli showpass ${APP_FQI} ${aaf_locator_fqdn} | grep cadi_keystore_password_p12 | cut -d '=' -f 2- | tr -d '\n' > /opt/app/osaaf/p12.pass
/opt/app/aaf_config/bin/agent.sh aafcli showpass ${APP_FQI} ${aaf_locator_fqdn} | grep cadi_keystore_password_jks= | cut -d '=' -f 2- | tr -d '\n' > /opt/app/osaaf/jks.pass
# AAF provides a truststore password, but it appears that the truststore is not password-protected
/opt/app/aaf_config/bin/agent.sh aafcli showpass ${APP_FQI} ${aaf_locator_fqdn} | grep cadi_truststore_password= | cut -d '=' -f 2- | tr -d '\n' > /opt/app/osaaf/trust.pass

# Copy the p12 and JKS artifacts to target directory and rename according to DCAE conventions
cp ${ARTIFACTS}/${AAFNS}.p12 ${TARGET}/cert.p12
cp ${ARTIFACTS}/${AAFNS}.jks ${TARGET}/cert.jks
cp ${ARTIFACTS}/${AAFNS}.trust.jks ${TARGET}/trust.jks

# Break out the cert and key (unencrypted) from the p12
openssl pkcs12 -in ${TARGET}/cert.p12 -passin file:${TARGET}/p12.pass -nodes -nokeys -out ${TARGET}/cert.pem
openssl pkcs12 -in ${TARGET}/cert.p12 -passin file:${TARGET}/p12.pass -nodes -nocerts -out ${TARGET}/key.pem
chmod 644 ${TARGET}/cert.pem ${TARGET}/key.pem

# Get the ONAP AAF CA certificate -- pass in an empty password, since the trust store doesn't have one
echo "" | keytool -exportcert -rfc -file ${TARGET}/cacert.pem -keystore ${ARTIFACTS}/${AAFNS}.trust.jks -alias ca_local_0

# Remove server-related files for client-only components
if [ "${TLS_SERVER}" == "false" ]
then
    rm ${TARGET}/cert.p12 ${TARGET}/cert.jks ${TARGET}/cert.pem ${TARGET}/key.pem ${TARGET}/p12.pass ${TARGET}/jks.pass
    rm ${ARTIFACTS}/${AAFNS}.p12 ${ARTIFACTS}/${AAFNS}.jks
fi