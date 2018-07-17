#!/bin/bash
sed -e 's#{{ ONAPTEMPLATE_RAWREPOURL_org_onap_dcaegen2_platform_plugins_releases }}#https://nexus.onap.org/content/sites/raw/org.onap.dcaegen2.platform.plugins/R3#g' Dockerfile-template > Dockerfile
